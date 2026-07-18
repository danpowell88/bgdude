/// Free-text meal estimation: model path and no-model fallback (issue #79).
library;

import 'package:bgdude/food/food_database.dart';
import 'package:bgdude/food/food_item.dart';
import 'package:bgdude/food/meal_estimate.dart';
import 'package:bgdude/food/meal_estimate_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEstimator implements MealEstimator {
  _FakeEstimator({this.available = true, this.result, this.throws = false});

  @override
  final bool available;
  final MealEstimate? result;
  final bool throws;
  int calls = 0;

  @override
  Future<MealEstimate?> estimate(String description) async {
    calls++;
    if (throws) throw Exception('model OOM');
    return result;
  }
}

class _FakeFoods implements FoodDatabase {
  _FakeFoods(this.byQuery, {this.throws = false});

  final Map<String, FoodItem> byQuery;
  final bool throws;
  final List<String> queries = [];

  @override
  String get name => 'fake';

  @override
  Future<FoodItem?> lookupBarcode(String gtin) async => null;

  @override
  Future<List<FoodItem>> searchByName(String query, {int limit = 20}) async {
    queries.add(query);
    if (throws) throw Exception('db unavailable');
    final hit = byQuery[query];
    return hit == null ? [] : [hit];
  }
}

FoodItem _food(String name, {double? carbs, double? serving}) => FoodItem(
      name: name,
      source: 'AFCD',
      carbsPer100g: carbs,
      servingSizeG: serving,
    );

MealEstimate _modelResult(List<MealEstimateItem> items) =>
    MealEstimate(items: items, source: MealEstimateSource.model);

void main() {
  test('uses the model when one is installed', () async {
    final estimator = _FakeEstimator(
      result: _modelResult(
        [const MealEstimateItem(name: 'burrito', grams: 300, carbsG: 65)],
      ),
    );
    final service = MealEstimateService(
      estimator: estimator,
      foods: _FakeFoods(const {}),
    );

    final estimate = (await service.estimate('chicken burrito'))!;

    expect(estimate.source, MealEstimateSource.model);
    expect(estimate.totalCarbsG, 65);
  });

  test('the model result is validated, not trusted as-is', () async {
    // 65 g of carbs in a 30 g biscuit — an order-of-magnitude slip that would read
    // as a plausible dose.
    final service = MealEstimateService(
      estimator: _FakeEstimator(
        result: _modelResult(
          [const MealEstimateItem(name: 'biscuit', grams: 30, carbsG: 65)],
        ),
      ),
      foods: _FakeFoods({'biscuit': _food('biscuit', carbs: 60)}),
    );

    final estimate = (await service.estimate('biscuit'))!;

    // Nothing usable survived validation, so it fell back to the database rather
    // than showing a blank item.
    expect(estimate.source, MealEstimateSource.foodDatabase);
  });

  test('falls back to the food database when no model is installed', () async {
    final estimator = _FakeEstimator(available: false);
    final service = MealEstimateService(
      estimator: estimator,
      foods: _FakeFoods({
        'rice': _food('white rice, cooked', carbs: 28, serving: 150),
      }),
    );

    final estimate = (await service.estimate('rice'))!;

    expect(estimator.calls, 0, reason: 'must not call an unavailable model');
    expect(estimate.source, MealEstimateSource.foodDatabase);
    expect(estimate.items.single.name, 'white rice, cooked');
    // 28 g per 100 g scaled to the item's own 150 g serving.
    expect(estimate.totalCarbsG, closeTo(42, 0.001));
  });

  test('a model that throws degrades to the database rather than failing',
      () async {
    final service = MealEstimateService(
      estimator: _FakeEstimator(throws: true),
      foods: _FakeFoods({'toast': _food('toast', carbs: 45)}),
    );

    final estimate = (await service.estimate('toast'))!;

    expect(estimate.source, MealEstimateSource.foodDatabase);
  });

  test('each dish in the description is looked up separately', () async {
    final foods = _FakeFoods({
      'rice': _food('rice', carbs: 28),
      'curry': _food('curry', carbs: 10),
    });
    final service = MealEstimateService(
      estimator: _FakeEstimator(available: false),
      foods: foods,
    );

    final estimate = (await service.estimate('rice and curry'))!;

    expect(foods.queries, ['rice', 'curry']);
    expect(estimate.items, hasLength(2));
    expect(estimate.totalCarbsG, closeTo(38, 0.001));
  });

  test('a dish with no match is still listed, with no numbers', () async {
    // Dropping it silently would leave the user under-counting a dish they ate.
    final service = MealEstimateService(
      estimator: _FakeEstimator(available: false),
      foods: _FakeFoods({'rice': _food('rice', carbs: 28)}),
    );

    final estimate = (await service.estimate('rice and pangalactic gargleblaster'))!;

    expect(estimate.items, hasLength(2));
    final unmatched = estimate.items.last;
    expect(unmatched.name, 'pangalactic gargleblaster');
    expect(unmatched.carbsG, isNull);
  });

  test('nothing usable returns null rather than a confident zero', () async {
    // A meal of 0 g carbs is a real answer; "I don't know" must not render as it.
    final service = MealEstimateService(
      estimator: _FakeEstimator(available: false),
      foods: _FakeFoods(const {}),
    );

    expect(await service.estimate('something unrecognisable'), isNull);
  });

  test('a failing food database does not throw', () async {
    final service = MealEstimateService(
      estimator: _FakeEstimator(available: false),
      foods: _FakeFoods(const {}, throws: true),
    );

    expect(await service.estimate('rice'), isNull);
  });

  test('empty input asks nothing of anyone', () async {
    final estimator = _FakeEstimator();
    final foods = _FakeFoods(const {});
    final service = MealEstimateService(estimator: estimator, foods: foods);

    expect(await service.estimate('   '), isNull);
    expect(estimator.calls, 0);
    expect(foods.queries, isEmpty);
  });
}
