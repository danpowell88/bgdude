import 'package:bgdude/meals/fpu_coach.dart';
import 'package:bgdude/meals/meal_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FpuCoach', () {
    const coach = FpuCoach();

    test('computes FPU and a split dose for a fat/protein-heavy meal', () {
      // 60g carb, 30g fat, 40g protein, ICR 10 g/U.
      // FPU = (30*9 + 40*4)/100 = (270+160)/100 = 4.3.
      final a = coach.advise(
        carbsGrams: 60,
        fatGrams: 30,
        proteinGrams: 40,
        insulinToCarbRatio: 10,
      );
      expect(a.fpu, closeTo(4.3, 1e-9));
      expect(a.immediateUnits, closeTo(6.0, 1e-9)); // 60/10
      expect(a.extendedUnits, closeTo(4.3, 1e-9)); // 4.3 FPU * 10 / 10
      expect(a.recommendSplit, isTrue);
      expect(a.extendHours, inInclusiveRange(3, 8));
      expect(a.totalUnits, closeTo(10.3, 1e-9));
    });

    test('a lean, low-fat meal does not warrant a split', () {
      final a = coach.advise(
        carbsGrams: 40,
        fatGrams: 2,
        proteinGrams: 5,
        insulinToCarbRatio: 10,
      );
      expect(a.recommendSplit, isFalse); // FPU = (18+20)/100 = 0.38
    });

    test('warrantsSplit falls back to the fatProteinHeavy flag when macros unknown', () {
      expect(
          coach.warrantsSplit(
              fatGrams: 0, proteinGrams: 0, fatProteinHeavy: true),
          isTrue);
      expect(
          coach.warrantsSplit(
              fatGrams: 0, proteinGrams: 0, fatProteinHeavy: false),
          isFalse);
    });

    test('zero ICR is handled safely', () {
      final a = coach.advise(
          carbsGrams: 60, fatGrams: 30, proteinGrams: 40, insulinToCarbRatio: 0);
      expect(a.totalUnits, 0);
    });
  });

  group('SavedMeal macros', () {
    test('fat/protein grams round-trip through JSON', () {
      const meal = SavedMeal(
        id: 'pizza',
        name: 'Pizza',
        carbsGrams: 60,
        fatGrams: 28,
        proteinGrams: 35,
        fatProteinHeavy: true,
      );
      final restored = SavedMeal.fromJson(meal.toJson());
      expect(restored.fatGrams, 28);
      expect(restored.proteinGrams, 35);
      expect(restored.fatProteinHeavy, isTrue);
    });

    test('older JSON without macros defaults to 0', () {
      final restored = SavedMeal.fromJson({
        'id': 'x',
        'name': 'X',
        'carbsGrams': 30,
      });
      expect(restored.fatGrams, 0);
      expect(restored.proteinGrams, 0);
    });
  });
}
