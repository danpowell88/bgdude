/// The Therapy report: how the user's *learned* insulin sensitivity has trended over the
/// range (Autotune per day), so drift away from pump settings is visible. The screen pairs
/// this with the learned time-of-day profile and the current basal suggestions.
///
/// Advisory only — nothing here writes to the pump.
library;

import '../analytics/therapy_settings.dart';
import '../core/samples.dart';
import '../ml/autotune.dart';
import 'report_range.dart';

class TherapyReport {
  const TherapyReport({
    required this.range,
    required this.generatedAt,
    required this.days,
    required this.avgMultiplier,
  });

  final ReportRange range;
  final DateTime generatedAt;

  /// Per-day Autotune results with a usable signal (carb-free observation).
  final List<DayResult> days;

  /// Confidence-weighted average resistance multiplier (>1 resistant, <1 sensitive).
  final double avgMultiplier;

  bool get hasData => days.isNotEmpty;
}

class TherapyReportBuilder {
  TherapyReportBuilder({Autotune? autotune})
      : autotune = autotune ?? Autotune();

  final Autotune autotune;

  TherapyReport build({
    required List<CgmSample> cgm,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required List<CarbEntry> carbs,
    required TherapySettings settings,
    required ReportRange range,
    required DateTime now,
  }) {
    final startDay = DateTime(range.from.year, range.from.month, range.from.day);
    final endDay = DateTime(range.to.year, range.to.month, range.to.day);

    final results = <DayResult>[];
    for (var d = startDay;
        !d.isAfter(endDay);
        d = d.add(const Duration(days: 1))) {
      final dayStart = d.subtract(const Duration(hours: 6)); // IOB lookback
      final dayEnd = d.add(const Duration(days: 1));
      final dayCgm = [
        for (final s in cgm)
          if (!s.time.isBefore(dayStart) && s.time.isBefore(dayEnd)) s,
      ];
      if (dayCgm.length < 12) continue;
      final r = autotune.analyseDay(
        day: d,
        cgm: dayCgm,
        boluses: boluses,
        basal: basal,
        carbs: carbs,
        settings: settings,
      );
      if (r.carbFreeMinutes > 0) results.add(r);
    }

    var weighted = 0.0;
    var weight = 0.0;
    for (final r in results) {
      weighted += r.sensitivityMultiplier * r.confidence;
      weight += r.confidence;
    }

    return TherapyReport(
      range: range,
      generatedAt: now,
      days: results,
      avgMultiplier: weight <= 0 ? 1.0 : weighted / weight,
    );
  }
}
