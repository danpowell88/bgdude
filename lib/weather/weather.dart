/// Ambient weather via Open-Meteo — free, no API key. Heat accelerates insulin absorption
/// and peripheral vasodilation (→ more hypos); cold has paradoxical hypo effects too. We
/// use current temperature to nudge the low-alert threshold and to correlate against daily
/// glucose. Location is a city the user types (geocoded once) — no device GPS. Data is
/// CC-BY (attributed in About).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class GeoLocation {
  const GeoLocation({required this.name, required this.lat, required this.lon});
  final String name;
  final double lat;
  final double lon;
}

class Weather {
  const Weather({required this.tempC, this.humidity, required this.at});
  final double tempC;
  final double? humidity;
  final DateTime at;
}

class WeatherSettings {
  const WeatherSettings({this.enabled = false, this.city = '', this.lat, this.lon});
  final bool enabled;
  final String city;
  final double? lat;
  final double? lon;

  bool get ready => enabled && lat != null && lon != null;

  WeatherSettings copyWith(
          {bool? enabled, String? city, double? lat, double? lon}) =>
      WeatherSettings(
        enabled: enabled ?? this.enabled,
        city: city ?? this.city,
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
      );

  Map<String, dynamic> toJson() =>
      {'enabled': enabled, 'city': city, 'lat': lat, 'lon': lon};

  factory WeatherSettings.fromJson(Map<String, dynamic> j) => WeatherSettings(
        enabled: j['enabled'] as bool? ?? false,
        city: j['city'] as String? ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
      );
}

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _headers = {'User-Agent': 'bgdude/0.1 (personal T1D companion)'};

  /// Resolve a city name to coordinates via Open-Meteo's free geocoding API.
  Future<GeoLocation?> geocode(String city) async {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search',
        {'name': city, 'count': '1'});
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) return null;
    return parseGeocode(res.body);
  }

  /// Current temperature + humidity for [lat],[lon].
  Future<Weather?> current(double lat, double lon, {DateTime? now}) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$lat',
      'longitude': '$lon',
      'current': 'temperature_2m,relative_humidity_2m',
    });
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) return null;
    return parseCurrent(res.body, now: now);
  }

  /// TASK-208/269: Open-Meteo's shape is stable today, but a hard `as Map` cast on
  /// a malformed/unexpected body would throw a [TypeError] straight out of a parser
  /// with no caller-side guard — an is-Map check degrades to "no result" instead.
  /// [jsonDecode] itself must be guarded too: a non-JSON body (captive-portal HTML,
  /// a truncated or empty response returned with HTTP 200) throws a
  /// [FormatException] before the is-Map check ever runs, the exact
  /// throws-out-of-a-parser-at-the-source case this guard exists to prevent.
  static GeoLocation? parseGeocode(String body) {
    final decoded = _tryDecode(body);
    if (decoded is! Map) return null;
    final json = decoded.cast<String, dynamic>();
    final results = (json['results'] as List?) ?? const [];
    if (results.isEmpty) return null;
    final first = results.first;
    if (first is! Map) return null;
    final r = first.cast<String, dynamic>();
    final lat = (r['latitude'] as num?)?.toDouble();
    final lon = (r['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return GeoLocation(
      name: (r['name'] as String?) ?? 'Location',
      lat: lat,
      lon: lon,
    );
  }

  static Weather? parseCurrent(String body, {DateTime? now}) {
    final decoded = _tryDecode(body);
    if (decoded is! Map) return null;
    final json = decoded.cast<String, dynamic>();
    final curRaw = json['current'];
    final cur = curRaw is Map ? curRaw.cast<String, dynamic>() : null;
    final temp = (cur?['temperature_2m'] as num?)?.toDouble();
    if (temp == null) return null;
    return Weather(
      tempC: temp,
      humidity: (cur?['relative_humidity_2m'] as num?)?.toDouble(),
      at: now ?? DateTime.now(),
    );
  }

  /// TASK-269: `jsonDecode` throws [FormatException] on non-JSON input -- null
  /// degrades to the same "no result" path the is-Map check already uses for a
  /// wrong-shape (but validly-decoded) body.
  static Object? _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}

/// Turns ambient temperature into a low-alert-threshold bump: hot weather speeds insulin
/// absorption (hypo risk) and cold carries a paradoxical hypo risk, so alerts lead earlier
/// at both extremes.
class WeatherRiskModifier {
  const WeatherRiskModifier({
    this.hotC = 28,
    this.veryHotC = 34,
    this.coldC = 5,
    this.hotBumpMgdl = 5,
    this.veryHotBumpMgdl = 8,
    this.coldBumpMgdl = 3,
  });

  final double hotC;
  final double veryHotC;
  final double coldC;
  final double hotBumpMgdl;
  final double veryHotBumpMgdl;
  final double coldBumpMgdl;

  double lowThresholdBump(double? tempC) {
    if (tempC == null) return 0;
    if (tempC >= veryHotC) return veryHotBumpMgdl;
    if (tempC >= hotC) return hotBumpMgdl;
    if (tempC <= coldC) return coldBumpMgdl;
    return 0;
  }
}
