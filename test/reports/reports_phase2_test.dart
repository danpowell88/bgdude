import 'package:bgdude/core/samples.dart';
import 'package:bgdude/meals/meal_library.dart';
import 'package:bgdude/reports/insulin_report.dart';
import 'package:bgdude/reports/meals_report.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:flutter_test/flutter_test.dart';

ReportRange _range(DateTime from, DateTime to) =>
    ReportRange(from: from, to: to, preset: ReportPreset.custom);

void main() {
  group('InsulinReportBuilder', () {
    final from = DateTime(2026, 7, 4);
    final to = DateTime(2026, 7, 6);
    final range = _range(from, to);

    test('splits bolus vs basal and classifies boluses', () {
      final report = const InsulinReportBuilder().build(
        boluses: [
          BolusEvent(time: DateTime(2026, 7, 4, 8), units: 5, carbsGrams: 40),
          BolusEvent(time: DateTime(2026, 7, 4, 15), units: 2), // correction
        ],
        basal: [BasalSegment(start: from, end: to, unitsPerHour: 1.0)],
        range: range,
        now: DateTime(2026, 7, 6, 8),
      );
      expect(report.hasData, isTrue);
      expect(report.activeDays, 2); // 7/4 and 7/5 (7/6 midnight has zero span)
      expect(report.avgBasal, closeTo(24, 1e-6));
      expect(report.bolusCount, 2);
      expect(report.mealBolusCount, 1);
      expect(report.correctionBolusCount, 1);
      expect(report.avgBolusUnits, closeTo(3.5, 1e-9));
      expect(report.basalFraction, greaterThan(0.8)); // basal-dominant
    });

    test('Control-IQ auto-boluses are NOT manual corrections', () {
      final report = const InsulinReportBuilder().build(
        boluses: [
          BolusEvent(time: DateTime(2026, 7, 4, 8), units: 5, carbsGrams: 40),
          BolusEvent(time: DateTime(2026, 7, 4, 15), units: 2), // manual corr.
          BolusEvent(
              time: DateTime(2026, 7, 4, 16), units: 0.4, isAutomatic: true),
          BolusEvent(
              time: DateTime(2026, 7, 4, 17), units: 0.3, isAutomatic: true),
          BolusEvent(
              time: DateTime(2026, 7, 5, 3), units: 0.5, isAutomatic: true),
        ],
        basal: const [],
        range: range,
        now: DateTime(2026, 7, 6, 8),
      );
      expect(report.bolusCount, 5);
      expect(report.mealBolusCount, 1);
      expect(report.correctionBolusCount, 1,
          reason: 'loop microboluses must not count as user behaviour');
      expect(report.autoBolusCount, 3);
    });

    test(
        'TASK-151: Control-IQ workload metrics -- per-day auto units/count and '
        'the loop-delivered fraction of all bolus insulin', () {
      final report = const InsulinReportBuilder().build(
        boluses: [
          BolusEvent(time: DateTime(2026, 7, 4, 8), units: 5, carbsGrams: 40),
          BolusEvent(time: DateTime(2026, 7, 4, 15), units: 2), // manual corr.
          BolusEvent(
              time: DateTime(2026, 7, 4, 16), units: 0.4, isAutomatic: true),
          BolusEvent(
              time: DateTime(2026, 7, 4, 17), units: 0.3, isAutomatic: true),
          BolusEvent(
              time: DateTime(2026, 7, 5, 3), units: 0.5, isAutomatic: true),
        ],
        basal: const [],
        range: range,
        now: DateTime(2026, 7, 6, 8),
      );
      // 2 active days: 7/4 (0.4+0.3=0.7 auto U, 2 events), 7/5 (0.5 auto U, 1
      // event) -- per-day averages over those 2 active days.
      expect(report.avgAutoBolusUnits, closeTo(0.6, 1e-9));
      expect(report.avgAutoCorrectionCount, closeTo(1.5, 1e-9));
      // 1.2 auto U out of 8.2 total bolus U.
      expect(report.loopBolusFraction, closeTo(1.2 / 8.2, 1e-9));

      final day74 =
          report.days.firstWhere((d) => d.date == DateTime(2026, 7, 4));
      expect(day74.autoBolusUnits, closeTo(0.7, 1e-9));
      expect(day74.autoBolusCount, 2);
      final day75 =
          report.days.firstWhere((d) => d.date == DateTime(2026, 7, 5));
      expect(day75.autoBolusUnits, closeTo(0.5, 1e-9));
      expect(day75.autoBolusCount, 1);
    });

    test('no automatic boluses -> workload metrics are all zero, not NaN', () {
      final report = const InsulinReportBuilder().build(
        boluses: [
          BolusEvent(time: DateTime(2026, 7, 4, 8), units: 5, carbsGrams: 40),
        ],
        basal: const [],
        range: range,
        now: DateTime(2026, 7, 6, 8),
      );
      expect(report.avgAutoBolusUnits, 0);
      expect(report.avgAutoCorrectionCount, 0);
      expect(report.loopBolusFraction, 0);
    });

    test('empty history → no data', () {
      final report = const InsulinReportBuilder().build(
        boluses: const [],
        basal: const [],
        range: range,
        now: DateTime(2026, 7, 6, 8),
      );
      expect(report.hasData, isFalse);
    });
  });

  group('MealsReportBuilder', () {
    final range = _range(DateTime(2026, 7, 1), DateTime(2026, 7, 8));

    MealOutcome outcome(DateTime at, double bgAtMeal, double peak) => MealOutcome(
          eatenAt: at,
          preBolusMinutes: 10,
          bolusUnits: 4,
          bgAtMealMgdl: bgAtMeal,
          peakMgdl: peak,
          peakOffsetMinutes: 60,
          bgAt3hMgdl: bgAtMeal + 10,
          timeAbove180Minutes: 20,
        );

    test('aggregates per-meal outcomes within range and sorts by excursion', () {
      final library = MealLibrary(meals: [
        SavedMeal(id: 'pasta', name: 'Pasta', carbsGrams: 60, outcomes: [
          outcome(DateTime(2026, 7, 3, 19), 120, 230), // +110
          outcome(DateTime(2026, 7, 5, 19), 120, 210), // +90 → avg +100
          outcome(DateTime(2026, 6, 1, 19), 120, 300), // out of range, ignored
        ]),
        SavedMeal(id: 'salad', name: 'Salad', carbsGrams: 20, outcomes: [
          outcome(DateTime(2026, 7, 4, 13), 120, 150), // +30
        ]),
      ]);

      final report = const MealsReportBuilder()
          .build(library: library, range: range, now: DateTime(2026, 7, 8));

      expect(report.totalOutcomes, 3); // 2 pasta + 1 salad in range
      expect(report.meals, hasLength(2));
      // Sorted worst-excursion first → pasta before salad.
      expect(report.meals.first.name, 'Pasta');
      expect(report.meals.first.count, 2);
      expect(report.meals.first.avgExcursionMgdl, closeTo(100, 1e-9));
      expect(report.overallAvgPreBolusMin, 10);
    });

    test('no outcomes in range → no data', () {
      final library = MealLibrary(meals: [
        SavedMeal(id: 'x', name: 'X', carbsGrams: 10, outcomes: [
          outcome(DateTime(2020, 1, 1), 120, 200),
        ]),
      ]);
      final report = const MealsReportBuilder()
          .build(library: library, range: range, now: DateTime(2026, 7, 8));
      expect(report.hasData, isFalse);
    });
  });
}
