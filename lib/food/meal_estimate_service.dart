/// Turning a typed meal description into macros (issue #79).
///
/// Prefers the on-device model; falls back to a name search against the bundled food
/// database when no model is installed. The fallback is the point, not an afterthought:
/// the model is an optional ~0.5 GB download, so the common case is not having one, and
/// the feature has to be useful anyway.
library;

import '../logging/app_log.dart';
import 'food_database.dart';
import 'food_item.dart';
import 'meal_estimate.dart';

/// The on-device model's estimate step, kept behind an interface so the service is
/// testable without a real model.
abstract interface class MealEstimator {
  /// Whether a model is installed and ready.
  bool get available;

  /// Estimate macros for [description], or null when it can't.
  Future<MealEstimate?> estimate(String description);
}

/// Default: no model installed.
class NoopMealEstimator implements MealEstimator {
  const NoopMealEstimator();
  @override
  bool get available => false;
  @override
  Future<MealEstimate?> estimate(String description) async => null;
}

class MealEstimateService {
  MealEstimateService({required this.estimator, required this.foods});

  final MealEstimator estimator;

  /// Used for the no-model fallback (and when the model returns nothing usable).
  final FoodDatabase foods;

  /// Estimate the macros of a typed meal description.
  ///
  /// Returns null when neither path can say anything, so the caller shows "couldn't
  /// estimate" rather than a confident zero — a meal of 0 g carbs is a real answer and
  /// must not be how "I don't know" renders.
  Future<MealEstimate?> estimate(String description) async {
    if (description.trim().isEmpty) return null;

    if (estimator.available) {
      try {
        final raw = await estimator.estimate(description);
        if (raw != null) {
          final validated = validateMealEstimate(raw);
          // A validated-to-nothing answer is worse than no answer: fall through to the
          // database rather than presenting a list of blank items.
          if (_hasAnyMacro(validated)) return validated;
        }
      } catch (e) {
        appLog.error('meal_estimate', 'model estimate failed', error: e);
        // Fall through — degrade, never block.
      }
    }

    return _fromFoodDatabase(description);
  }

  /// Name-search each dish phrase and scale the best match to a nominal portion.
  Future<MealEstimate?> _fromFoodDatabase(String description) async {
    final phrases = splitMealDescription(description);
    if (phrases.isEmpty) return null;

    final items = <MealEstimateItem>[];
    for (final phrase in phrases) {
      final FoodItem? match;
      try {
        final results = await foods.searchByName(phrase, limit: 1);
        match = results.isEmpty ? null : results.first;
      } catch (e) {
        appLog.error('meal_estimate', 'food search failed', error: e);
        continue;
      }
      if (match == null) {
        // Keep the phrase with no numbers rather than dropping it silently — the user
        // needs to see that this dish was NOT counted, or they'll under-bolus for it.
        items.add(MealEstimateItem(name: phrase));
        continue;
      }
      // Per-100 g macros scaled to the item's own serving size where it has one, else a
      // nominal 100 g. Labelled an estimate and editable either way.
      final grams = match.servingSizeG ?? 100;
      double? scale(double? per100) =>
          per100 == null ? null : per100 * grams / 100.0;
      items.add(MealEstimateItem(
        name: match.name,
        grams: grams,
        carbsG: scale(match.carbsPer100g),
        fatG: scale(match.fatPer100g),
        proteinG: scale(match.proteinPer100g),
      ));
    }

    final estimate = validateMealEstimate(
      MealEstimate(items: items, source: MealEstimateSource.foodDatabase),
    );
    return _hasAnyMacro(estimate) ? estimate : null;
  }

  static bool _hasAnyMacro(MealEstimate e) => e.items.any((i) =>
      i.carbsG != null || i.fatG != null || i.proteinG != null);
}
