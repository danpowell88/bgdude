/// The Insulin report: daily total insulin (TDD = bolus + integrated basal), the
/// basal/bolus split, and bolus behaviour (meal vs correction, size, frequency), over
/// the report range. Derived from our own delivery history via [insulinTotals].
library;

import '../analytics/insulin_totals.dart';
import '../core/samples.dart';
import 'report_range.dart';

class DailyInsulin {
  const DailyInsulin({required this.date, required this.bolus, required this.basal});
  final DateTime date;
  final double bolus;
  final double basal;
  double get total => bolus + basal;
}

class InsulinReport {
  const InsulinReport({
    required this.range,
    required this.generatedAt,
    required this.days,
    required this.avgTdd,
    required this.avgBolus,
    required this.avgBasal,
    required this.basalFraction,
    required this.bolusCount,
    required this.mealBolusCount,
    required this.correctionBolusCount,
    required this.autoBolusCount,
    required this.avgBolusUnits,
    required this.bolusesPerDay,
    required this.activeDays,
  });

  final ReportRange range;
  final DateTime generatedAt;
  final List<DailyInsulin> days;

  final double avgTdd;
  final double avgBolus;
  final double avgBasal;
  final double basalFraction;

  final int bolusCount;
  final int mealBolusCount;

  /// MANUAL corrections only (TASK-148) — Control-IQ auto-boluses are counted
  /// separately in [autoBolusCount], not as user behaviour.
  final int correctionBolusCount;

  /// Control-IQ automatic (micro)boluses in range.
  final int autoBolusCount;
  final double avgBolusUnits;
  final double bolusesPerDay;

  /// Days in range with any delivery recorded.
  final int activeDays;

  bool get hasData => activeDays > 0 || bolusCount > 0;
}

class InsulinReportBuilder {
  const InsulinReportBuilder();

  InsulinReport build({
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required ReportRange range,
    required DateTime now,
  }) {
    final days = <DailyInsulin>[];
    final startDay = DateTime(range.from.year, range.from.month, range.from.day);
    final endDay = DateTime(range.to.year, range.to.month, range.to.day);
    for (var d = startDay;
        !d.isAfter(endDay);
        d = d.add(const Duration(days: 1))) {
      final dayStart = d;
      var dayEnd = d.add(const Duration(days: 1));
      if (dayEnd.isAfter(range.to)) dayEnd = range.to;
      final t = insulinTotals(
          boluses: boluses, basal: basal, from: dayStart, to: dayEnd);
      days.add(DailyInsulin(date: d, bolus: t.bolus, basal: t.basal));
    }

    final active = days.where((d) => d.total > 0).toList();
    final activeDays = active.length;
    double avg(double Function(DailyInsulin) sel) => activeDays == 0
        ? 0
        : active.map(sel).reduce((a, b) => a + b) / activeDays;
    final avgBolus = avg((d) => d.bolus);
    final avgBasal = avg((d) => d.basal);
    final avgTdd = avgBolus + avgBasal;

    final inRange = boluses
        .where((b) => range.contains(b.time) && b.units > 0)
        .toList();
    // TASK-148: partition meal / manual-correction / automatic. Counting loop
    // microboluses as manual corrections misstated user behaviour.
    final auto = inRange.where((b) => b.isAutomatic).length;
    final meal = inRange.where((b) => !b.isAutomatic && b.carbsGrams > 0).length;
    final correction = inRange.length - auto - meal;
    final avgUnits = inRange.isEmpty
        ? 0.0
        : inRange.map((b) => b.units).reduce((a, b) => a + b) / inRange.length;

    return InsulinReport(
      range: range,
      generatedAt: now,
      days: days,
      avgTdd: avgTdd,
      avgBolus: avgBolus,
      avgBasal: avgBasal,
      basalFraction: avgTdd <= 0 ? 0 : avgBasal / avgTdd,
      bolusCount: inRange.length,
      mealBolusCount: meal,
      correctionBolusCount: correction,
      autoBolusCount: auto,
      avgBolusUnits: avgUnits,
      bolusesPerDay: activeDays == 0 ? 0 : inRange.length / activeDays,
      activeDays: activeDays,
    );
  }
}
