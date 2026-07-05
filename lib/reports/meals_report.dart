/// The Meals report: per-meal performance from confirmed, matured meal outcomes
/// (`SavedMeal.outcomes`) within the range — excursion, time-to-peak, time-above-180,
/// pre-bolus timing, and how well glucose returned to baseline. Only real outcomes count.
library;

import '../meals/meal_library.dart';
import 'report_range.dart';

class MealPerformance {
  const MealPerformance({
    required this.mealId,
    required this.name,
    required this.emoji,
    required this.count,
    required this.carbsGrams,
    required this.avgExcursionMgdl,
    required this.avgTimeToPeakMin,
    required this.avgTimeAbove180Min,
    required this.avgPreBolusMin,
    required this.avgReturnDeltaMgdl,
  });

  final String mealId;
  final String name;
  final String emoji;
  final int count;
  final double carbsGrams;

  /// Peak − baseline (bgAtMeal). Lower is better.
  final double avgExcursionMgdl;
  final double avgTimeToPeakMin;
  final double avgTimeAbove180Min;
  final double avgPreBolusMin;

  /// bgAt3h − bgAtMeal: how far from baseline it settled (near 0 is ideal).
  final double avgReturnDeltaMgdl;
}

class MealsReport {
  const MealsReport({
    required this.range,
    required this.generatedAt,
    required this.meals,
    required this.totalOutcomes,
    required this.overallAvgPreBolusMin,
    required this.overallAvgExcursionMgdl,
  });

  final ReportRange range;
  final DateTime generatedAt;

  /// Sorted worst-excursion first (the meals most worth attention).
  final List<MealPerformance> meals;
  final int totalOutcomes;
  final double overallAvgPreBolusMin;
  final double overallAvgExcursionMgdl;

  bool get hasData => totalOutcomes > 0;
}

class MealsReportBuilder {
  const MealsReportBuilder();

  MealsReport build({
    required MealLibrary library,
    required ReportRange range,
    required DateTime now,
  }) {
    final perf = <MealPerformance>[];
    var totalOutcomes = 0;
    var preBolusSum = 0.0;
    var excursionSum = 0.0;

    for (final meal in library.meals) {
      final outcomes =
          meal.outcomes.where((o) => range.contains(o.eatenAt)).toList();
      if (outcomes.isEmpty) continue;
      double avg(double Function(MealOutcome o) sel) =>
          outcomes.map(sel).reduce((a, b) => a + b) / outcomes.length;

      final excursion = avg((o) => o.peakMgdl - o.bgAtMealMgdl);
      perf.add(MealPerformance(
        mealId: meal.id,
        name: meal.name,
        emoji: meal.emoji,
        count: outcomes.length,
        carbsGrams: meal.carbsGrams,
        avgExcursionMgdl: excursion,
        avgTimeToPeakMin: avg((o) => o.peakOffsetMinutes.toDouble()),
        avgTimeAbove180Min: avg((o) => o.timeAbove180Minutes.toDouble()),
        avgPreBolusMin: avg((o) => o.preBolusMinutes.toDouble()),
        avgReturnDeltaMgdl: avg((o) => o.bgAt3hMgdl - o.bgAtMealMgdl),
      ));

      for (final o in outcomes) {
        totalOutcomes++;
        preBolusSum += o.preBolusMinutes;
        excursionSum += o.peakMgdl - o.bgAtMealMgdl;
      }
    }

    perf.sort((a, b) => b.avgExcursionMgdl.compareTo(a.avgExcursionMgdl));

    return MealsReport(
      range: range,
      generatedAt: now,
      meals: perf,
      totalOutcomes: totalOutcomes,
      overallAvgPreBolusMin:
          totalOutcomes == 0 ? 0 : preBolusSum / totalOutcomes,
      overallAvgExcursionMgdl:
          totalOutcomes == 0 ? 0 : excursionSum / totalOutcomes,
    );
  }
}
