/// Structured nutrition read from a photographed **nutrition panel** (not from a picture
/// of the food). Values are captured per-serve and/or per-100 g exactly as the label
/// states; the app converts to a portion via [toFoodItem]. Carbohydrate is the field that
/// matters most (it drives the meal's carb count and bolus advice), so it's always shown
/// for the user to confirm/correct — nothing here doses anything by itself.
library;

import 'food_item.dart';

/// One nutrient's values as printed on the label. Either column may be null.
class PanelValue {
  const PanelValue({this.perServe, this.per100g});
  final double? perServe;
  final double? per100g;

  bool get isEmpty => perServe == null && per100g == null;

  /// Per-100 g value, deriving it from the per-serve value + [servingSizeG] when the
  /// label only printed a per-serve column.
  double? per100gOr(double? servingSizeG) {
    if (per100g != null) return per100g;
    if (perServe != null && servingSizeG != null && servingSizeG > 0) {
      return perServe! / servingSizeG * 100.0;
    }
    return null;
  }
}

class PanelNutrition {
  const PanelNutrition({
    this.servingSizeG,
    this.servingsPerPackage,
    this.carbs = const PanelValue(),
    this.sugars = const PanelValue(),
    this.fat = const PanelValue(),
    this.protein = const PanelValue(),
    this.energyKj = const PanelValue(),
    this.sodiumMg = const PanelValue(),
    this.fibre = const PanelValue(),
    this.rawText = '',
    this.source = 'Label scan',
  });

  final double? servingSizeG;
  final double? servingsPerPackage;

  final PanelValue carbs; // grams
  final PanelValue sugars; // grams
  final PanelValue fat; // grams
  final PanelValue protein; // grams
  final PanelValue energyKj; // kilojoules
  final PanelValue sodiumMg; // milligrams
  final PanelValue fibre; // grams

  /// The OCR text this was parsed from — kept for the confirm screen / debugging.
  final String rawText;
  final String source;

  /// Whether carbohydrate — the field the meal actually needs — was found.
  bool get hasCarbs => carbs.per100gOr(servingSizeG) != null;

  /// A coarse 0–1 confidence: did we get the fields that matter? Used to decide whether to
  /// fall back to the LLM normaliser.
  double get confidence {
    var score = 0.0;
    if (hasCarbs) score += 0.6;
    if (!protein.isEmpty) score += 0.15;
    if (!fat.isEmpty) score += 0.15;
    if (servingSizeG != null) score += 0.1;
    return score;
  }

  /// Convert to the app's [FoodItem] (per-100 g macros + serving size) so it flows through
  /// the same prefill/confirm path as barcode and name-search results.
  FoodItem toFoodItem({String? name}) => FoodItem(
        name: name == null || name.trim().isEmpty ? 'Scanned label' : name.trim(),
        source: source,
        carbsPer100g: carbs.per100gOr(servingSizeG),
        fatPer100g: fat.per100gOr(servingSizeG),
        proteinPer100g: protein.per100gOr(servingSizeG),
        servingSizeG: servingSizeG,
      );

  PanelNutrition copyWith({String? rawText, String? source}) => PanelNutrition(
        servingSizeG: servingSizeG,
        servingsPerPackage: servingsPerPackage,
        carbs: carbs,
        sugars: sugars,
        fat: fat,
        protein: protein,
        energyKj: energyKj,
        sodiumMg: sodiumMg,
        fibre: fibre,
        rawText: rawText ?? this.rawText,
        source: source ?? this.source,
      );
}
