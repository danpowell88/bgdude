import 'package:bgdude/analytics/bolus_advisor.dart';
import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/meals/meal_library.dart';
import 'package:bgdude/meals/prebolus_coach.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/samples.dart';

void main() {
  final now = DateTime(2026, 7, 4, 18);
  final settings = testTherapySettings();

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

  test(
      'a LEARNED fat/protein signature (no manual flag) also gets the '
      'split-bolus note (TASK-153: effectiveFatProteinHeavy, not just the '
      'manual flag)', () {
    const learnedHeavy = SavedMeal(
      id: 'learned-heavy',
      name: 'Curry',
      carbsGrams: 55,
      fatProteinHeavy: false,
      fatProteinTailScore: 0.6, // above SavedMeal.fatProteinHeavyThreshold
      absorptionMinutes: 300,
      peakOffsetMinutes: 120,
    );
    final advice = coach.advise(meal: learnedHeavy, state: state(bg: 130));
    expect(advice.notes.any((n) => n.contains('extended/split')), isTrue);
  });

  test(
      'a below-threshold learned score does NOT get the split-bolus note '
      '(only effectiveFatProteinHeavy crossing the threshold should)', () {
    const learnedMild = SavedMeal(
      id: 'learned-mild',
      name: 'Sandwich',
      carbsGrams: 55,
      fatProteinHeavy: false,
      fatProteinTailScore: 0.4, // below SavedMeal.fatProteinHeavyThreshold
      absorptionMinutes: 180,
      peakOffsetMinutes: 90,
    );
    final advice = coach.advise(meal: learnedMild, state: state(bg: 130));
    expect(advice.notes.any((n) => n.contains('extended/split')), isFalse);
  });
}
