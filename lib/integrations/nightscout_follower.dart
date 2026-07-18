/// Reading FROM Nightscout — "follower mode" (issue #75).
///
/// bgdude has always been able to push to Nightscout; this is the other direction, so
/// the app can run off a Nightscout site (or blend it with the pump) instead of only
/// feeding it.
///
/// Everything here is pure: parsing and the merge decision take strings and values and
/// return values, with no HTTP and no database. That matters because the interesting
/// behaviour — not double-ingesting a reading the pump already gave us — is exactly the
/// part that would otherwise only be testable against a live site.
library;

import 'dart:convert';

import '../core/samples.dart';

/// One `entries` document from Nightscout.
class NightscoutEntry {
  const NightscoutEntry({
    required this.id,
    required this.time,
    required this.mgdl,
    this.direction,
  });

  /// Nightscout's `_id`. Carried for provenance and idempotency: re-fetching an
  /// overlapping window must not re-ingest what we already have.
  final String id;
  final DateTime time;
  final double mgdl;
  final String? direction;

  CgmSample toSample() => CgmSample(
        time: time,
        mgdl: mgdl,
        trend: trendFromDirection(direction),
        source: GlucoseSource.nightscout,
      );
}

/// One `treatments` document from Nightscout.
class NightscoutTreatment {
  const NightscoutTreatment({
    required this.id,
    required this.time,
    required this.eventType,
    this.insulinUnits,
    this.carbsGrams,
  });

  final String id;
  final DateTime time;
  final String eventType;
  final double? insulinUnits;
  final double? carbsGrams;

  bool get hasDose => (insulinUnits ?? 0) > 0 || (carbsGrams ?? 0) > 0;
}

/// Nightscout's `direction` string back to a [GlucoseTrend].
///
/// The inverse of `NightscoutClient.directionFor`. Unknown or absent directions become
/// [GlucoseTrend.unknown] rather than flat — "no arrow" and "not moving" are different
/// claims, and treating the first as the second invents a trend the site never reported.
GlucoseTrend trendFromDirection(String? direction) => switch (direction) {
      'DoubleUp' => GlucoseTrend.doubleUp,
      'SingleUp' => GlucoseTrend.singleUp,
      'FortyFiveUp' => GlucoseTrend.fortyFiveUp,
      'Flat' => GlucoseTrend.flat,
      'FortyFiveDown' => GlucoseTrend.fortyFiveDown,
      'SingleDown' => GlucoseTrend.singleDown,
      'DoubleDown' => GlucoseTrend.doubleDown,
      _ => GlucoseTrend.unknown,
    };

/// Parses an `/api/v1/entries` response body.
///
/// Skips documents that are not usable readings rather than failing the batch: a single
/// malformed entry on a site with years of history must not stop the other 287 from
/// being read. Non-`sgv` types (calibrations, meter batches) are excluded because they
/// are not sensor readings.
List<NightscoutEntry> parseEntries(String body) {
  final decoded = _decodeList(body);
  final out = <NightscoutEntry>[];
  for (final doc in decoded) {
    if (doc is! Map) continue;
    final type = doc['type'];
    if (type != null && type != 'sgv') continue;
    final mgdl = _toDouble(doc['sgv']);
    final time = _timeOf(doc);
    if (mgdl == null || mgdl <= 0 || time == null) continue;
    out.add(NightscoutEntry(
      id: (doc['_id'] ?? '').toString(),
      time: time,
      mgdl: mgdl,
      direction: doc['direction'] as String?,
    ));
  }
  return out;
}

/// Parses an `/api/v1/treatments` response body.
List<NightscoutTreatment> parseTreatments(String body) {
  final decoded = _decodeList(body);
  final out = <NightscoutTreatment>[];
  for (final doc in decoded) {
    if (doc is! Map) continue;
    final time = _timeOf(doc);
    if (time == null) continue;
    out.add(NightscoutTreatment(
      id: (doc['_id'] ?? '').toString(),
      time: time,
      eventType: (doc['eventType'] ?? '').toString(),
      insulinUnits: _toDouble(doc['insulin']),
      carbsGrams: _toDouble(doc['carbs']),
    ));
  }
  return out;
}

/// Which fetched entries should actually be written.
///
/// [existingTimes] are the timestamps already held locally from a HIGHER-priority
/// source (the pump / its own sensor). Those win: the pump is the device the readings
/// physically came from, and Nightscout is very often a copy of the same data pushed
/// there by this app — ingesting both would double-count the identical reading.
///
/// [knownIds] are Nightscout `_id`s already ingested, so re-fetching an overlapping
/// window (which every polling loop does) is idempotent.
///
/// Also de-duplicates within the batch itself: a site can return two documents for one
/// timestamp, and the local table has a UNIQUE(time) constraint that such a batch would
/// otherwise violate mid-write.
List<NightscoutEntry> entriesToIngest(
  Iterable<NightscoutEntry> fetched, {
  Set<DateTime> existingTimes = const {},
  Set<String> knownIds = const {},
}) {
  final seenTimes = <DateTime>{};
  final out = <NightscoutEntry>[];
  for (final e in fetched) {
    // Compare on the same local-wall-clock basis CgmSample normalises to, or a UTC
    // string from the site would never match a local timestamp from the pump.
    final t = e.time.isUtc ? e.time.toLocal() : e.time;
    if (existingTimes.contains(t)) continue;
    if (e.id.isNotEmpty && knownIds.contains(e.id)) continue;
    if (!seenTimes.add(t)) continue;
    out.add(e);
  }
  return out;
}

List<dynamic> _decodeList(String body) {
  if (body.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(body);
    return decoded is List ? decoded : const [];
  } catch (_) {
    // A site behind a login wall returns an HTML page, not JSON. That is a
    // configuration problem, not a crash.
    return const [];
  }
}

double? _toDouble(Object? v) => switch (v) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };

/// Nightscout documents carry both an epoch-millis `date` and an ISO `dateString`;
/// sites and uploaders vary in which they set, so accept either.
DateTime? _timeOf(Map<dynamic, dynamic> doc) {
  final date = doc['date'];
  if (date is num) {
    return DateTime.fromMillisecondsSinceEpoch(date.toInt(), isUtc: true)
        .toLocal();
  }
  for (final key in ['dateString', 'created_at', 'timestamp']) {
    final raw = doc[key];
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.toLocal();
    }
  }
  return null;
}
