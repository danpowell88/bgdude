/// Free-text meal → macros: prompt, parsing and validation (issue #79).
library;

import 'package:bgdude/food/meal_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildMealEstimatePrompt', () {
    test('includes the description and demands JSON only', () {
      final prompt = buildMealEstimatePrompt('chicken burrito and chips');

      expect(prompt, contains('chicken burrito and chips'));
      expect(prompt, contains('ONLY a JSON object'));
      // Small models pad answers when not told what to do with unknowns.
      expect(prompt, contains('never guess a number you have no basis for'));
    });
  });

  group('parseMealEstimateJson', () {
    test('parses an itemised response', () {
      final estimate = parseMealEstimateJson(
        '{"items":[{"name":"burrito","grams":300,"carbs_g":65,"fat_g":18,'
        '"protein_g":30}]}',
      )!;

      expect(estimate.items.single.name, 'burrito');
      expect(estimate.items.single.grams, 300);
      expect(estimate.totalCarbsG, 65);
      expect(estimate.source, MealEstimateSource.model);
    });

    test('tolerates a code fence and surrounding prose', () {
      // Small on-device models do this constantly despite being told not to.
      final estimate = parseMealEstimateJson('''
Sure! Here is the estimate:
```json
{"items":[{"name":"toast","grams":60,"carbs_g":30}]}
```
Hope that helps.
''')!;

      expect(estimate.items.single.name, 'toast');
      expect(estimate.totalCarbsG, 30);
    });

    test('stops at the first BALANCED object, not the last brace', () {
      // Taking first-{ to last-} would swallow the trailing text and fail to parse,
      // losing an otherwise-good answer.
      final estimate = parseMealEstimateJson(
        '{"items":[{"name":"rice","carbs_g":45}]} and here is another {thing}',
      )!;

      expect(estimate.items.single.name, 'rice');
    });

    test('a brace inside a string does not end the object early', () {
      final estimate = parseMealEstimateJson(
        r'{"items":[{"name":"rice {special}","carbs_g":45}]}',
      )!;

      expect(estimate.items.single.name, 'rice {special}');
    });

    test('null macros are preserved rather than becoming zero', () {
      // Zero carbs is a real claim; "unknown" must not render as it.
      final estimate = parseMealEstimateJson(
        '{"items":[{"name":"black coffee","carbs_g":null,"fat_g":null}]}',
      )!;

      expect(estimate.items.single.carbsG, isNull);
    });

    test('string numbers are accepted', () {
      final estimate = parseMealEstimateJson(
        '{"items":[{"name":"apple","carbs_g":"21"}]}',
      )!;

      expect(estimate.totalCarbsG, 21);
    });

    test('unusable responses return null, not an empty estimate', () {
      // The caller must be able to fall back; an empty estimate looks like a real
      // answer of "nothing".
      for (final bad in [
        'I am not able to estimate that.',
        '',
        '{}',
        '{"items":[]}',
        '{"items":"not a list"}',
        '{"items":[{"grams":100}]}', // no name
        'not json at all {',
      ]) {
        expect(parseMealEstimateJson(bad), isNull, reason: bad);
      }
    });
  });

  group('validateMealEstimate', () {
    MealEstimate one(MealEstimateItem item) =>
        MealEstimate(items: [item], source: MealEstimateSource.model);

    test('numbers in the DESCRIPTION are not used to ground macros', () {
      // The label scanner keeps a value only if that number appears in the source
      // text, which is right for a printed label. Here the numbers are quantities
      // ("2 tacos", "500ml coke"), so applying that rule would null nearly
      // everything and quietly make the feature useless.
      final estimate = validateMealEstimate(one(const MealEstimateItem(
        name: '2 tacos and a 500ml coke',
        grams: 400,
        carbsG: 87,
      )));

      expect(estimate.items.single.carbsG, 87);
    });

    test('a macro larger than its own portion is dropped', () {
      // An order-of-magnitude slip that bare bounds would let through, and that would
      // read as a perfectly plausible dose.
      final estimate = validateMealEstimate(one(const MealEstimateItem(
        name: 'biscuit',
        grams: 30,
        carbsG: 65,
      )));

      expect(estimate.items.single.carbsG, isNull);
      expect(estimate.items.single.grams, 30, reason: 'the portion is still fine');
    });

    test('a macro equal to its portion is allowed', () {
      // Pure sugar is legitimately ~100% carbohydrate.
      final estimate = validateMealEstimate(one(const MealEstimateItem(
        name: 'sugar',
        grams: 10,
        carbsG: 10,
      )));

      expect(estimate.items.single.carbsG, 10);
    });

    test('negative, NaN and absurd values are nulled', () {
      final estimate = validateMealEstimate(one(const MealEstimateItem(
        name: 'nonsense',
        grams: 100,
        carbsG: -5,
        fatG: double.nan,
        proteinG: double.infinity,
      )));

      final item = estimate.items.single;
      expect(item.carbsG, isNull);
      expect(item.fatG, isNull);
      expect(item.proteinG, isNull);
    });

    test('an implausible portion is nulled without taking the macros with it', () {
      // Without a portion there is nothing to compare against, so the macros are
      // still the best information available.
      final estimate = validateMealEstimate(one(const MealEstimateItem(
        name: 'huge',
        grams: 99999,
        carbsG: 60,
      )));

      expect(estimate.items.single.grams, isNull);
      expect(estimate.items.single.carbsG, 60);
    });

    test('the item name survives validation', () {
      // Even a fully-nulled item must still be shown, so the user sees the dish was
      // not counted rather than silently losing it.
      final estimate = validateMealEstimate(one(const MealEstimateItem(
        name: 'mystery stew',
        carbsG: -1,
      )));

      expect(estimate.items.single.name, 'mystery stew');
    });
  });

  group('splitMealDescription', () {
    test('splits on the separators people actually type', () {
      expect(
        splitMealDescription('chicken burrito, chips and a coke'),
        ['chicken burrito', 'chips', 'a coke'],
      );
      expect(splitMealDescription('toast with jam'), ['toast', 'jam']);
      expect(splitMealDescription('rice + curry'), ['rice', 'curry']);
    });

    test('a single dish stays one item', () {
      expect(splitMealDescription('chicken burrito'), ['chicken burrito']);
    });

    test('empty and whitespace-only input yields nothing', () {
      expect(splitMealDescription(''), isEmpty);
      expect(splitMealDescription('  ,  , '), isEmpty);
    });

    test('"and" inside a word is not a separator', () {
      // Splitting "sandwich" into "s"/"wich" would be a memorable bug.
      expect(splitMealDescription('sandwich'), ['sandwich']);
    });
  });
}
