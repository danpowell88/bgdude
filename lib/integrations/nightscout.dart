/// Nightscout upload bridge.
///
/// Pushes CGM readings, treatments (boluses / carbs) and device status (IOB) to a
/// self-hosted Nightscout site (the xDrip / AndroidAPS ecosystem). Nightscout
/// authenticates writes with an `api-secret` header whose value is the *SHA1 hex*
/// of the site's plaintext API secret.
///
/// The payload builders on [NightscoutClient] are pure, static, and IO-free so the
/// document shapes and trend→direction mapping can be unit tested without a network
/// or an [http.Client].
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../core/samples.dart';

final Logger _log = Logger('nightscout');

/// Connection settings for a single Nightscout site.
///
/// [apiSecret] is stored as the *plaintext* secret; the SHA1 hash actually sent on
/// the wire is derived on demand (see [NightscoutClient._secretHeader]). Persist this
/// via `toJson`/`fromJson` (e.g. into shared_preferences).
class NightscoutConfig {
  const NightscoutConfig({
    this.baseUrl = '',
    this.apiSecret = '',
    this.enabled = false,
  });

  /// Base site URL, e.g. `https://my-nightscout.up.railway.app`. Trailing slashes
  /// are tolerated (they are trimmed before request paths are built).
  final String baseUrl;

  /// Plaintext API secret (>= 12 chars per Nightscout convention). The SHA1 hex of
  /// this value is what goes in the `api-secret` header.
  final String apiSecret;

  /// Master switch. When false, [NightscoutClient] uploads no-op silently.
  final bool enabled;

  /// True only when uploads can actually be attempted.
  bool get isUsable => enabled && baseUrl.trim().isNotEmpty;

  NightscoutConfig copyWith({
    String? baseUrl,
    String? apiSecret,
    bool? enabled,
  }) {
    return NightscoutConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiSecret: apiSecret ?? this.apiSecret,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'baseUrl': baseUrl,
        'apiSecret': apiSecret,
        'enabled': enabled,
      };

  factory NightscoutConfig.fromJson(Map<String, dynamic> json) {
    return NightscoutConfig(
      baseUrl: (json['baseUrl'] as String?) ?? '',
      apiSecret: (json['apiSecret'] as String?) ?? '',
      enabled: (json['enabled'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NightscoutConfig &&
      other.baseUrl == baseUrl &&
      other.apiSecret == apiSecret &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(baseUrl, apiSecret, enabled);

  @override
  String toString() =>
      'NightscoutConfig(baseUrl: $baseUrl, enabled: $enabled, apiSecret: ${apiSecret.isEmpty ? '<empty>' : '<set>'})';
}

/// Uploads bgdude data to a Nightscout site.
///
/// All `upload*` methods are best-effort: they no-op when the config is unusable and
/// swallow (log) network errors so callers on the data-sync path never see a throw.
class NightscoutClient {
  NightscoutClient(this.config, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final NightscoutConfig config;
  final http.Client _http;

  // ---------------------------------------------------------------------------
  // Pure payload builders (static, no IO — fully unit-testable).
  // ---------------------------------------------------------------------------

  /// Nightscout arrow direction string for a [GlucoseTrend].
  ///
  /// These are the canonical Nightscout `direction` values consumed by xDrip and the
  /// Nightscout UI.
  static String directionFor(GlucoseTrend trend) => switch (trend) {
        GlucoseTrend.doubleUp => 'DoubleUp',
        GlucoseTrend.singleUp => 'SingleUp',
        GlucoseTrend.fortyFiveUp => 'FortyFiveUp',
        GlucoseTrend.flat => 'Flat',
        GlucoseTrend.fortyFiveDown => 'FortyFiveDown',
        GlucoseTrend.singleDown => 'SingleDown',
        GlucoseTrend.doubleDown => 'DoubleDown',
        GlucoseTrend.unknown => 'NONE',
      };

  /// Build a Nightscout `entries` document (an `sgv` reading) from a [CgmSample].
  static Map<String, dynamic> entryFromCgm(CgmSample sample) {
    final DateTime t = sample.time.toUtc();
    return <String, dynamic>{
      'type': 'sgv',
      'dateString': t.toIso8601String(),
      'date': sample.time.millisecondsSinceEpoch,
      'sgv': sample.mgdl.round(),
      'direction': directionFor(sample.trend),
      'device': 'bgdude',
    };
  }

  /// Build a Nightscout `treatments` document from a [BolusEvent].
  ///
  /// Uses `Meal Bolus` when carbs accompany the dose, otherwise a plain `Bolus`.
  static Map<String, dynamic> treatmentFromBolus(BolusEvent bolus) {
    final bool hasCarbs = bolus.carbsGrams > 0;
    final Map<String, dynamic> doc = <String, dynamic>{
      'eventType': hasCarbs ? 'Meal Bolus' : 'Bolus',
      'insulin': bolus.units,
      'created_at': bolus.time.toUtc().toIso8601String(),
      'enteredBy': 'bgdude',
    };
    if (hasCarbs) {
      doc['carbs'] = bolus.carbsGrams;
    }
    return doc;
  }

  /// Build a Nightscout `treatments` document from a standalone [CarbEntry].
  static Map<String, dynamic> treatmentFromCarb(CarbEntry carb) {
    return <String, dynamic>{
      'eventType': 'Carb Correction',
      'carbs': carb.grams,
      'created_at': carb.time.toUtc().toIso8601String(),
      'enteredBy': 'bgdude',
    };
  }

  /// Build a Nightscout `devicestatus` document reporting insulin-on-board.
  ///
  /// Emits IOB both in the OpenAPS-shaped block (consumed by AndroidAPS-style
  /// tooling) and as a top-level `iob` for simpler readers.
  static Map<String, dynamic> devicestatus({
    required double iob,
    DateTime? at,
  }) {
    final DateTime t = (at ?? DateTime.now()).toUtc();
    final String createdAt = t.toIso8601String();
    return <String, dynamic>{
      'device': 'bgdude',
      'created_at': createdAt,
      'openaps': <String, dynamic>{
        'iob': <String, dynamic>{
          'iob': iob,
          'timestamp': createdAt,
        },
      },
      'iob': <String, dynamic>{
        'iob': iob,
        'timestamp': createdAt,
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Wire helpers.
  // ---------------------------------------------------------------------------

  /// The `api-secret` header value: the lowercase SHA1 hex of the plaintext secret.
  String _secretHeader() =>
      sha1.convert(utf8.encode(config.apiSecret)).toString();

  String _trimmedBase() {
    var b = config.baseUrl.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return b;
  }

  Uri _endpoint(String path) => Uri.parse('${_trimmedBase()}$path');

  Map<String, String> _headers() => <String, String>{
        'Content-Type': 'application/json',
        'api-secret': _secretHeader(),
      };

  Future<void> _postJson(String path, List<Map<String, dynamic>> docs) async {
    if (!config.isUsable) {
      _log.fine('Nightscout upload skipped (disabled or no baseUrl).');
      return;
    }
    if (docs.isEmpty) return;
    final Uri url = _endpoint(path);
    try {
      final http.Response res = await _http.post(
        url,
        headers: _headers(),
        body: jsonEncode(docs),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        _log.warning(
            'Nightscout POST $path failed: ${res.statusCode} ${res.body}');
      } else {
        _log.fine('Nightscout POST $path ok (${docs.length} docs).');
      }
    } catch (e, st) {
      // Never propagate: uploads are best-effort background work.
      _log.warning('Nightscout POST $path error: $e', e, st);
    }
  }

  // ---------------------------------------------------------------------------
  // Uploads.
  // ---------------------------------------------------------------------------

  /// POST CGM readings to `/api/v1/entries`.
  Future<void> uploadEntries(List<CgmSample> samples) async {
    await _postJson(
      '/api/v1/entries',
      samples.map(entryFromCgm).toList(growable: false),
    );
  }

  /// POST treatments to `/api/v1/treatments`.
  ///
  /// Accepts a mixed list of [BolusEvent] and [CarbEntry]; each is mapped to the
  /// appropriate document. Unknown types are skipped (logged).
  Future<void> uploadTreatments(List<dynamic> treatments) async {
    final List<Map<String, dynamic>> docs = <Map<String, dynamic>>[];
    for (final dynamic t in treatments) {
      if (t is BolusEvent) {
        docs.add(treatmentFromBolus(t));
      } else if (t is CarbEntry) {
        docs.add(treatmentFromCarb(t));
      } else {
        _log.warning('Nightscout uploadTreatments: unsupported type '
            '${t.runtimeType}, skipping.');
      }
    }
    await _postJson('/api/v1/treatments', docs);
  }

  /// POST a device-status IOB report to `/api/v1/devicestatus`.
  Future<void> uploadDeviceStatus({required double iob, DateTime? at}) async {
    await _postJson(
      '/api/v1/devicestatus',
      <Map<String, dynamic>>[devicestatus(iob: iob, at: at)],
    );
  }

  /// Probe `/api/v1/status.json`. Returns true on a 2xx, false on any error.
  ///
  /// Does not require the config to be `enabled` (this is used from a "Test" button),
  /// but does need a non-empty baseUrl.
  Future<bool> testConnection() async {
    if (_trimmedBase().isEmpty) return false;
    try {
      final http.Response res = await _http.get(
        _endpoint('/api/v1/status.json'),
        headers: <String, String>{'api-secret': _secretHeader()},
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      _log.warning('Nightscout testConnection error: $e');
      return false;
    }
  }

  /// Release the underlying [http.Client] (only if bgdude owns it).
  void close() => _http.close();
}
