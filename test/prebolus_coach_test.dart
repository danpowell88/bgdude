import 'package:bgdude/analytics/bolus_advisor.dart';
import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/meals/meal_library.dart';
import 'package:bgdude/meals/prebolus_coach.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 4, 18);
  const settings = TherapySettings(
    segments: [
      TherapySegment(
        startMinuteOfDay: 0,
        isf: 50,
        carbRatio: 10,
        targetMgdl: 100,
        basalUnitsPerHour: 0.8,
      ),
    ],
  );

  const meal = SavedMeal(
    id: 'm',
    name: 'Pasta',
    carbsGrams: 60,
    absorptionMinutes: 180,
    peakOffsetMinutes: 90,
  );

  PredictionState state({required double bg, double roc = 0}) =>
      PredictionState(
        now: now,
        currentMgdl: bg,
        recentRocMgdlPerMin: roc,
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: settings,
        context: SensitivityContext.neutral,
      );

  final coach = PreBolusCoach();

  test('recommends a meaningful lead for steady in-range glucose', () {
    final advice = coach.advise(meal: meal, state: state(bg: 120));
    expect(advice.bolusAfterEating, isFalse);
    expect(advice.recommendedMinutes, greaterThanOrEqualTo(10));
    expect(advice.working, isNotEmpty);
  });

  test('peak with the recommended lead is no worse than with none', () {
    final advice = coach.advise(meal: meal, state: state(bg: 130));
    expect(advice.predictedPeakWithMgdl,
        lessThanOrEqualTo(advice.predictedPeakWithoutMgdl + 0.01));
  });

  test('low glucose → eat first, bolus after', () {
    final advice = coach.advise(meal: meal, state: state(bg: 75));
    expect(advice.bolusAfterEating, isTrue);
    expect(advice.recommendedMinutes, 0);
    expect(advice.notes.any((n) => n.contains('eat first')), isTrue);
  });

  test('falling fast → eat first even from in-range', () {
    final advice = coach.advise(meal: meal, state: state(bg: 110, roc: -2.5));
    expect(advice.bolusAfterEating, isTrue);
  });

  test('high and rising → longest safe lead', () {
    final advice = coach.advise(meal: meal, state: state(bg: 220, roc: 1.5));
    expect(advice.bolusAfterEating, isFalse);
    expect(advice.recommendedMinutes, greaterThanOrEqualTo(20));
  });

  test('confidence scales with logged outcomes', () {
    final none = coach.advise(meal: meal, state: state(bg: 120));
    expect(none.confidence, AdviceConfidence.low);

    var seasoned = meal;
    for (var i = 0; i < 3; i++) {
      seasoned = seasoned.withOutcome(MealOutcome(
        eatenAt: now.subtract(Duration(days: i + 1)),
        preBolusMinutes: 15,
        bolusUnits: 6,
        bgAtMealMgdl: 110,
        peakMgdl: 170,
        peakOffsetMinutes: 80,
        bgAt3hMgdl: 125,
        timeAbove180Minutes: 0,
      ));
    }
    final trusted = coach.advise(meal: seasoned, state: state(bg: 120));
    expect(trusted.confidence, AdviceConfidence.high);
  });

  test('fat/protein-heavy meal gets the split-bolus note', () {
    const pizza = SavedMeal(
      id: 'p',
      name: 'Pizza',
      carbsGrams: 70,
      fatProteinHeavy: true,
      absorptionMinutes: 300,
      peakOffsetMinutes: 120,
    );
    final advice = coach.advise(meal: pizza, state: state(bg: 130));
    expect(advice.notes.any((n) => n.contains('extended/split')), isTrue);
  });
}
