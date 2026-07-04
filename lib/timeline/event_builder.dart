/// Derives the day's [DayEvent] stream from [DayData] by combining logged events
/// (meals/boluses) with the ML detectors (unannounced meals, compression lows) and
/// simple threshold scans (sustained highs/lows). Pure Dart and deterministic so it is
/// unit-testable and reused by both the timeline UI and any future digest.
library;

import '../core/samples.dart';
import '../core/units.dart';
import '../ml/event_detectors.dart';
import '../state/day_data.dart';
import 'day_event.dart';

class EventBuilder {
  EventBuilder({
    MealDetector? mealDetector,
    CompressionLowDetector? compressionDetector,
    this.unit = GlucoseUnit.mmol,
  })  : _meals = mealDetector ?? MealDetector(),
        _compression = compressionDetector ?? CompressionLowDetector();

  final MealDetector _meals;
  final CompressionLowDetector _compression;
  final GlucoseUnit unit;

  /// Minimum minutes a reading must stay out of range to become a high/low event.
  static const int _sustainMinutes = 20;

  List<DayEvent> build(DayData day, {bool Function(DateTime)? isAsleep}) {
    final events = <DayEvent>[];
    String g(double m) => '${Mgdl(m).display(unit)} ${unit.label}';

    // Logged boluses (and the carbs attached to them).
    for (var i = 0; i < day.boluses.length; i++) {
      final b = day.boluses[i];
      if (b.carbsGrams > 0) {
        events.add(DayEvent(
          id: 'meal-$i-${b.time.millisecondsSinceEpoch}',
          type: DayEventType.meal,
          time: b.time,
          title: '${b.carbsGrams.toStringAsFixed(0)} g meal',
          detail: 'Bolused ${b.units.toStringAsFixed(1)} U',
        ));
      } else {
        events.add(DayEvent(
          id: 'bolus-$i-${b.time.millisecondsSinceEpoch}',
          type: DayEventType.bolus,
          time: b.time,
          title: '${b.units.toStringAsFixed(1)} U bolus',
          detail: b.isAutomatic ? 'Control-IQ auto correction' : 'Manual bolus',
        ));
      }
    }

    // Detected unannounced meals (rises not covered by a logged bolus/carb).
    final detected = _meals.detect(
      cgm: day.cgm,
      boluses: day.boluses,
      basal: day.basal,
      settings: day.settings,
    );
    for (final m in detected) {
      // Skip if it lines up with a logged meal (already represented).
      final nearLogged = day.carbs.any(
          (c) => (c.time.difference(m.time).inMinutes).abs() < 45);
      if (nearLogged) continue;
      events.add(DayEvent(
        id: 'detmeal-${m.time.millisecondsSinceEpoch}',
        type: DayEventType.detectedMeal,
        time: m.time,
        title: 'Unannounced rise',
        detail:
            '~${m.estimatedCarbsGrams.round()} g equivalent — tap to log or explain',
        suggestedCarbsGrams: m.estimatedCarbsGrams,
        explainable: true,
      ));
    }

    // Compression lows (nocturnal artefacts) — pre-tagged as ignore/compression.
    // Prefer samples already flagged (by the detector at ingest, or by the simulator);
    // fall back to a live detector pass when nothing is pre-flagged.
    var comps = _flaggedCompressionRuns(day, g);
    if (comps.isEmpty) {
      final asleep = isAsleep ?? _defaultAsleep;
      final detected = _compression.detect(
        cgm: day.cgm,
        boluses: day.boluses,
        basal: day.basal,
        settings: day.settings,
        isAsleep: asleep,
      );
      comps = [
        for (final c in detected)
          DayEvent(
            id: 'comp-${c.start.millisecondsSinceEpoch}',
            type: DayEventType.compressionLow,
            time: c.start,
            title: 'Compression low',
            detail: 'Sharp dip to ${g(c.nadir)} with fast rebound — likely sensor '
                'pressure, not a true low.',
            mgdl: c.nadir,
            explainable: true,
            disposition: ModelDisposition.ignore,
            ignoreReason: IgnoreReason.compressionLow,
          ),
      ];
    }
    events.addAll(comps);

    // Sustained highs and lows from the CGM trace (compression samples excluded via
    // their flag inside _rangeEvents).
    events.addAll(_rangeEvents(day, g));

    events.sort((a, b) => a.time.compareTo(b.time));
    return events;
  }

  /// Groups consecutive samples already flagged as compression lows into events.
  List<DayEvent> _flaggedCompressionRuns(DayData day, String Function(double) g) {
    final samples = [...day.cgm]..sort((a, b) => a.time.compareTo(b.time));
    final out = <DayEvent>[];
    DateTime? start;
    double nadir = double.infinity;
    DateTime? prev;
    for (final s in samples) {
      final flagged = s.compressionLow;
      final contiguous = prev == null || s.time.difference(prev).inMinutes <= 15;
      if (flagged && (start == null || contiguous)) {
        start ??= s.time;
        nadir = s.mgdl < nadir ? s.mgdl : nadir;
      } else if (!flagged && start != null) {
        out.add(_compressionEvent(start, nadir, g));
        start = null;
        nadir = double.infinity;
      }
      prev = flagged ? s.time : prev;
    }
    if (start != null) out.add(_compressionEvent(start, nadir, g));
    return out;
  }

  DayEvent _compressionEvent(
          DateTime start, double nadir, String Function(double) g) =>
      DayEvent(
        id: 'comp-${start.millisecondsSinceEpoch}',
        type: DayEventType.compressionLow,
        time: start,
        title: 'Compression low',
        detail: 'Sharp dip to ${g(nadir)} with fast rebound — likely sensor '
            'pressure, not a true low.',
        mgdl: nadir,
        explainable: true,
        disposition: ModelDisposition.ignore,
        ignoreReason: IgnoreReason.compressionLow,
      );

  List<DayEvent> _rangeEvents(DayData day, String Function(double) g) {
    final out = <DayEvent>[];
    final samples = [...day.cgm]
      ..removeWhere((s) => s.sensorWarmup || s.compressionLow || s.mgdl <= 0)
      ..sort((a, b) => a.time.compareTo(b.time));

    _scan(
      samples,
      test: (s) => s.mgdl > GlucoseThresholds.high,
      onSpan: (start, peak, end) => out.add(DayEvent(
        id: 'high-${start.millisecondsSinceEpoch}',
        type: DayEventType.high,
        time: start,
        endTime: end,
        title: 'High — peak ${g(peak)}',
        detail: 'Above range from ${_hm(start)} to ${_hm(end)}',
        mgdl: peak,
        explainable: true,
      )),
      pickExtreme: (a, b) => a > b, // track max
    );

    _scan(
      samples,
      test: (s) => s.mgdl < GlucoseThresholds.low,
      onSpan: (start, nadir, end) => out.add(DayEvent(
        id: 'low-${start.millisecondsSinceEpoch}',
        type: DayEventType.low,
        time: start,
        endTime: end,
        title: 'Low — nadir ${g(nadir)}',
        detail: 'Below range from ${_hm(start)} to ${_hm(end)}',
        mgdl: nadir,
        explainable: true,
      )),
      pickExtreme: (a, b) => a < b, // track min
    );

    return out;
  }

  void _scan(
    List<CgmSample> samples, {
    required bool Function(CgmSample) test,
    required void Function(DateTime start, double extreme, DateTime end) onSpan,
    required bool Function(double candidate, double current) pickExtreme,
  }) {
    DateTime? spanStart;
    DateTime? spanEnd;
    double? extreme;
    for (final s in samples) {
      if (test(s)) {
        spanStart ??= s.time;
        spanEnd = s.time;
        extreme = extreme == null || pickExtreme(s.mgdl, extreme) ? s.mgdl : extreme;
      } else if (spanStart != null) {
        if (spanEnd!.difference(spanStart).inMinutes >= _sustainMinutes) {
          onSpan(spanStart, extreme!, spanEnd);
        }
        spanStart = null;
        spanEnd = null;
        extreme = null;
      }
    }
    if (spanStart != null &&
        spanEnd!.difference(spanStart).inMinutes >= _sustainMinutes) {
      onSpan(spanStart, extreme!, spanEnd);
    }
  }

  static bool _defaultAsleep(DateTime t) => t.hour >= 23 || t.hour < 7;

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
