/// Menstrual-cycle glucose comparison: follicular vs luteal-phase time-in-range and mean
/// glucose, from confirmed CGM + Health Connect menstruation-flow data. Grounded in the
/// T1DEXI finding that mean glucose rises and TIR falls from the follicular to the late
/// luteal phase. Only shown when both phases have enough days.
library;

import '../analytics/metrics.dart';
import '../core/samples.dart';
import '../data/health_sync.dart';
import 'report_range.dart';

enum CyclePhase { follicular, luteal, unknown }

/// Detect period-start dates from menstruation-flow samples: a flow day is a *start* when
/// the previous flow day was more than 2 days earlier (or there was none).
List<DateTime> periodStarts(List<HealthSample> health) {
  final days = <DateTime>{
    for (final s in health)
      if (s.type == HealthMetric.menstruationFlow && s.value > 0)
        DateTime(s.time.year, s.time.month, s.time.day),
  }.toList()
    ..sort();
  final starts = <DateTime>[];
  for (var i = 0; i < days.length; i++) {
    if (i == 0 || days[i].difference(days[i - 1]).inDays > 2) starts.add(days[i]);
  }
  return starts;
}

/// Classify [day]'s cycle phase from [starts]: days 0–13 follicular, 14–28 luteal.
CyclePhase phaseFor(List<DateTime> starts, DateTime day) {
  DateTime? recent;
  for (final s in starts) {
    if (!s.isAfter(day)) recent = s;
  }
  if (recent == null) return CyclePhase.unknown;
  final n = day.difference(recent).inDays;
  if (n >= 0 && n <= 13) return CyclePhase.follicular;
  if (n >= 14 && n <= 28) return CyclePhase.luteal;
  return CyclePhase.unknown;
}

class CyclePhaseStats {
  const CyclePhaseStats({
    required this.days,
    required this.meanTir,
    required this.meanGlucoseMgdl,
  });
  final int days;
  final double meanTir; // 0..1
  final double meanGlucoseMgdl;
}

class CycleReport {
  const CycleReport({
    required this.range,
    required this.generatedAt,
    required this.follicular,
    required this.luteal,
    this.minDays = 3,
  });

  final ReportRange range;
  final DateTime generatedAt;
  final CyclePhaseStats follicular;
  final CyclePhaseStats luteal;
  final int minDays;

  bool get hasData => follicular.days >= minDays && luteal.days >= minDays;

  /// Percentage-point TIR difference (follicular − luteal); positive means the luteal
  /// phase ran worse, as the literature expects.
  double get tirDropToLuteal => (follicular.meanTir - luteal.meanTir) * 100;
}

class CycleReportBuilder {
  const CycleReportBuilder({this.minReadingsPerDay = 100});
  final int minReadingsPerDay;

  CycleReport build({
    required List<CgmSample> cgm,
    required List<HealthSample> health,
    required ReportRange range,
    required DateTime now,
  }) {
    final starts = periodStarts(health);

    final byDay = <String, List<CgmSample>>{};
    for (final s in cgm) {
      if (!range.contains(s.time) || s.sensorWarmup || s.mgdl <= 0) continue;
      (byDay['${s.time.year}-${s.time.month}-${s.time.day}'] ??= []).add(s);
    }

    const metrics = MetricsCalculator();
    final acc = {
      CyclePhase.follicular: <double>[],
      CyclePhase.luteal: <double>[],
    };
    final means = {
      CyclePhase.follicular: <double>[],
      CyclePhase.luteal: <double>[],
    };
    for (final e in byDay.entries) {
      if (e.value.length < minReadingsPerDay) continue;
      final day = e.value.first.time;
      final phase = phaseFor(starts, DateTime(day.year, day.month, day.day));
      if (phase == CyclePhase.unknown) continue;
      final m = metrics.compute(e.value);
      acc[phase]!.add(m.timeInRange);
      means[phase]!.add(m.meanMgdl);
    }

    CyclePhaseStats stats(CyclePhase p) {
      final tirs = acc[p]!;
      final ms = means[p]!;
      return CyclePhaseStats(
        days: tirs.length,
        meanTir: tirs.isEmpty ? 0 : tirs.reduce((a, b) => a + b) / tirs.length,
        meanGlucoseMgdl: ms.isEmpty ? 0 : ms.reduce((a, b) => a + b) / ms.length,
      );
    }

    return CycleReport(
      range: range,
      generatedAt: now,
      follicular: stats(CyclePhase.follicular),
      luteal: stats(CyclePhase.luteal),
    );
  }
}
