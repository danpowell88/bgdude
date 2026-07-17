import 'package:bgdude/core/samples.dart';
import 'package:bgdude/meals/meal_library.dart';
import 'package:flutter_test/flutter_test.dart';

/// A synthetic post-meal CGM trace rising from [baseline] to a peak at
/// [peakOffsetMin] and back down, sampled every 5 min for 3.5 h.
List<CgmSample> _mealTrace(
  DateTime eatenAt, {
  double baseline = 110,
  double rise = 80,
  int peakOffsetMin = 60,
}) {
  final out = <CgmSample>[];
  for (var m = -15; m <= 210; m += 5) {
    final double bg;
    if (m <= 0) {
      bg = baseline;
    } else if (m <= peakOffsetMin) {
      bg = baseline + rise * (m / peakOffsetMin);
    } else {
      final fall = (m - peakOffsetMin) / (210 - peakOffsetMin);
      bg = baseline + rise * (1 - fall).clamp(0.0, 1.0);
    }
    out.add(CgmSample(time: eatenAt.add(Duration(minutes: m)), mgdl: bg));
  }
  return out;
}

void main() {
  final eatenAt = DateTime(2026, 7, 4, 12);

  group('MealLibrary fuzzy find', () {
    test("'pizza' matches 'Pizza night'", () {
      final lib = MealLibrary(meals: [
        const SavedMeal(id: 'a', name: 'Pizza night', carbsGrams: 70),
        const SavedMeal(id: 'b', name: 'Porridge', carbsGrams: 40),
      ]);
      expect(lib.find('pizza')?.id, 'a');
      expect(lib.find('PIZZA NIGHT')?.id, 'a');
      expect(lib.find('sushi'), isNull);
    });

    test('search ranks exact match above substring', () {
      final lib = MealLibrary(meals: [
        const SavedMeal(id: 'a', name: 'Toast with jam', carbsGrams: 30),
        const SavedMeal(id: 'b', name: 'Toast', carbsGrams: 20),
      ]);
      final results = lib.search('toast');
      expect(results.first.id, 'b');
      expect(results, hasLength(2));
    });
  });

  group('Absorption learning', () {
    test('moves toward the observed peak with damping', () {
      var lib = MealLibrary();
      const meal = SavedMeal(
        id: 'm',
        name: 'Pasta',
        carbsGrams: 60,
        absorptionMinutes: 180,
        peakOffsetMinutes: 90,
      );
      lib = lib.add(meal);

      final outcome = MealOutcome.fromCgm(
        eatenAt: eatenAt,
        preBolusMinutes: 10,
        bolusUnits: 6,
        postMealCgm: _mealTrace(eatenAt, peakOffsetMin: 60),
      );
      final updated = lib
          .learnFromOutcome(meal, outcome, _mealTrace(eatenAt, peakOffsetMin: 60))
          .meal;

      // Damped: 90 + 0.3*(60-90) = 81, not a full jump to 60.
      expect(updated.peakOffsetMinutes, 81);
      // Absorption drifts toward 2×60=120: 180 + 0.3*(120-180) = 162.
      expect(updated.absorptionMinutes, 162);
      expect(updated.outcomes, hasLength(1));
    });

    test('learned parameters stay within physiological bounds', () {
      var lib = MealLibrary();
      var meal = const SavedMeal(
        id: 'm',
        name: 'Glucose gel',
        carbsGrams: 15,
        absorptionMinutes: 60,
        peakOffsetMinutes: 30,
      );
      lib = lib.add(meal);
      // Repeated ultra-fast meals can't push below the minimums.
      for (var i = 0; i < 10; i++) {
        final at = eatenAt.add(Duration(days: i));
        final trace = _mealTrace(at, peakOffsetMin: 15);
        meal = lib
            .learnFromOutcome(
              meal,
              MealOutcome.fromCgm(
                  eatenAt: at,
                  preBolusMinutes: 0,
                  bolusUnits: 1,
                  postMealCgm: trace),
              trace,
            )
            .meal;
      }
      expect(meal.absorptionMinutes,
          greaterThanOrEqualTo(SavedMeal.minAbsorptionMinutes));
      expect(meal.peakOffsetMinutes,
          greaterThanOrEqualTo(SavedMeal.minPeakOffsetMinutes));
    });

    test('flat trace (no meaningful rise) does not corrupt the curve', () {
      var lib = MealLibrary();
      const meal = SavedMeal(id: 'm', name: 'Salad', carbsGrams: 10);
      lib = lib.add(meal);
      final flat = [
        for (var m = -15; m <= 210; m += 5)
          CgmSample(time: eatenAt.add(Duration(minutes: m)), mgdl: 110),
      ];
      final updated = lib
          .learnFromOutcome(
            meal,
            MealOutcome.fromCgm(
                eatenAt: eatenAt,
                preBolusMinutes: 0,
                bolusUnits: 0.5,
                postMealCgm: flat),
            flat,
          )
          .meal;
      expect(updated.absorptionMinutes, meal.absorptionMinutes);
      expect(updated.peakOffsetMinutes, meal.peakOffsetMinutes);
    });

    test('outcome history is bounded to maxOutcomes', () {
      var meal = const SavedMeal(id: 'm', name: 'Toast', carbsGrams: 30);
      for (var i = 0; i < SavedMeal.maxOutcomes + 5; i++) {
        meal = meal.withOutcome(MealOutcome(
          eatenAt: eatenAt.add(Duration(days: i)),
          preBolusMinutes: 0,
          bolusUnits: 3,
          bgAtMealMgdl: 110,
          peakMgdl: 160,
          peakOffsetMinutes: 60,
          bgAt3hMgdl: 120,
          timeAbove180Minutes: 0,
        ));
      }
      expect(meal.outcomes, hasLength(SavedMeal.maxOutcomes));
      // Oldest were dropped: the first remaining is day 5.
      expect(meal.outcomes.first.eatenAt, eatenAt.add(const Duration(days: 5)));
    });
  });

  group('Fat/protein-tail learning (TASK-153)', () {
    MealOutcome tailOutcome(DateTime at) => MealOutcome(
          eatenAt: at,
          preBolusMinutes: 0,
          bolusUnits: 5,
          bgAtMealMgdl: 110,
          peakMgdl: 190,
          peakOffsetMinutes: 150, // late peak (well past a ~60-min carb-only peak)
          bgAt3hMgdl: 190, // still +80 above meal-time BG at +3h -- unresolved tail
          timeAbove180Minutes: 90,
        );

    MealOutcome resolvedOutcome(DateTime at) => MealOutcome(
          eatenAt: at,
          preBolusMinutes: 0,
          bolusUnits: 5,
          bgAtMealMgdl: 110,
          peakMgdl: 160,
          peakOffsetMinutes: 60, // typical carb-only peak
          bgAt3hMgdl: 110, // fully back to baseline -- no tail
          timeAbove180Minutes: 0,
        );

    test(
        'stays at 0 below minOutcomesForFatProteinLearning, even with a clear '
        'fat/protein pattern', () {
      var lib = MealLibrary();
      var meal = const SavedMeal(id: 'm', name: 'Pizza', carbsGrams: 60);
      lib = lib.add(meal);

      for (var i = 0; i < MealLibrary.minOutcomesForFatProteinLearning - 1; i++) {
        final at = eatenAt.add(Duration(days: i));
        final result =
            lib.learnFromOutcome(meal, tailOutcome(at), _mealTrace(at));
        lib = result.library;
        meal = result.meal;
      }
      expect(meal.outcomes,
          hasLength(MealLibrary.minOutcomesForFatProteinLearning - 1));
      expect(meal.fatProteinTailScore, 0);
    });

    test(
        'a consistent late-peak, unresolved-tail pattern damped-learns the score '
        'upward over several outcomes, crossing the heavy threshold', () {
      var lib = MealLibrary();
      var meal = const SavedMeal(id: 'm', name: 'Pizza', carbsGrams: 60);
      lib = lib.add(meal);

      for (var i = 0; i < MealLibrary.minOutcomesForFatProteinLearning; i++) {
        final at = eatenAt.add(Duration(days: i));
        final result =
            lib.learnFromOutcome(meal, tailOutcome(at), _mealTrace(at));
        lib = result.library;
        meal = result.meal;
      }
      // Observed signal is 1.0 (fully late peak + fully unresolved tail, both
      // clamp to 1.0), damped: 0 + 0.3*(1.0-0) = 0.3 -- not a full jump.
      expect(meal.fatProteinTailScore, closeTo(0.3, 1e-9));
      expect(meal.effectiveFatProteinHeavy, isFalse,
          reason: 'one learning pass is not yet past the 0.5 threshold');

      // One more consistent outcome pushes it further: 0.3 + 0.3*(1.0-0.3) = 0.51.
      final at = eatenAt.add(const Duration(days: 10));
      final result = lib.learnFromOutcome(meal, tailOutcome(at), _mealTrace(at));
      meal = result.meal;
      expect(meal.fatProteinTailScore, closeTo(0.51, 1e-9));
      expect(meal.effectiveFatProteinHeavy, isTrue);
    });

    test('a normal meal (early peak, fully resolved by +3h) keeps the score at 0',
        () {
      var lib = MealLibrary();
      var meal = const SavedMeal(id: 'm', name: 'Toast', carbsGrams: 30);
      lib = lib.add(meal);

      for (var i = 0; i < MealLibrary.minOutcomesForFatProteinLearning; i++) {
        final at = eatenAt.add(Duration(days: i));
        final result =
            lib.learnFromOutcome(meal, resolvedOutcome(at), _mealTrace(at));
        lib = result.library;
        meal = result.meal;
      }
      expect(meal.fatProteinTailScore, 0);
      expect(meal.effectiveFatProteinHeavy, isFalse);
    });
  });

  group('effectiveFatProteinHeavy', () {
    test('the manual flag wins even with a zero learned score', () {
      const meal = SavedMeal(
        id: 'm',
        name: 'X',
        carbsGrams: 10,
        fatProteinHeavy: true,
        fatProteinTailScore: 0,
      );
      expect(meal.effectiveFatProteinHeavy, isTrue);
    });

    test('the learned score decides when the manual flag is unset', () {
      const above = SavedMeal(
        id: 'm',
        name: 'X',
        carbsGrams: 10,
        fatProteinTailScore: 0.6,
      );
      const below = SavedMeal(
        id: 'm',
        name: 'X',
        carbsGrams: 10,
        fatProteinTailScore: 0.4,
      );
      expect(above.effectiveFatProteinHeavy, isTrue);
      expect(below.effectiveFatProteinHeavy, isFalse);
    });
  });

  group('MealOutcome.fromCgm', () {
    test('extracts peak, offset, and time-above-range', () {
      final outcome = MealOutcome.fromCgm(
        eatenAt: eatenAt,
        preBolusMinutes: 15,
        bolusUnits: 5,
        postMealCgm: _mealTrace(eatenAt, baseline: 120, rise: 100, peakOffsetMin: 75),
      );
      expect(outcome.bgAtMealMgdl, closeTo(120, 1));
      expect(outcome.peakMgdl, closeTo(220, 1));
      expect(outcome.peakOffsetMinutes, 75);
      expect(outcome.timeAbove180Minutes, greaterThan(0));
    });
  });

  test('SavedMeal JSON round-trip', () {
    final meal = const SavedMeal(
      id: 'x',
      name: 'Burrito',
      emoji: '🌯',
      category: MealCategory.takeaway,
      carbsGrams: 55,
      fatProteinHeavy: true,
      fatProteinTailScore: 0.42,
      absorptionMinutes: 240,
      peakOffsetMinutes: 100,
    ).withOutcome(MealOutcome(
      eatenAt: eatenAt,
      preBolusMinutes: 20,
      bolusUnits: 6,
      bgAtMealMgdl: 100,
      peakMgdl: 170,
      peakOffsetMinutes: 95,
      bgAt3hMgdl: 130,
      timeAbove180Minutes: 0,
    ));
    final restored = SavedMeal.fromJson(meal.toJson());
    expect(restored.name, 'Burrito');
    expect(restored.category, MealCategory.takeaway);
    expect(restored.fatProteinHeavy, isTrue);
    expect(restored.fatProteinTailScore, closeTo(0.42, 1e-9));
    expect(restored.absorptionMinutes, 240);
    expect(restored.outcomes, hasLength(1));
    expect(restored.outcomes.first.peakMgdl, 170);
  });

  test('a corrupt/out-of-range fatProteinTailScore clamps to [0, 1] on decode',
      () {
    final json = const SavedMeal(id: 'x', name: 'X', carbsGrams: 10).toJson();
    expect(SavedMeal.fromJson({...json, 'fatProteinTailScore': 5.0})
        .fatProteinTailScore, 1.0);
    expect(SavedMeal.fromJson({...json, 'fatProteinTailScore': -3.0})
        .fatProteinTailScore, 0.0);
    expect(SavedMeal.fromJson({...json, 'fatProteinTailScore': double.nan})
        .fatProteinTailScore, 0.0);
  });
}
