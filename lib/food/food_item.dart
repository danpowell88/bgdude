/// A food looked up from a food database (barcode or name search). Macros are per 100 g
/// where known; the UI converts to a portion. Carbs feed the meal's carb count and
/// fat/protein feed the FPU coach.
library;

class FoodItem {
  const FoodItem({
    required this.name,
    required this.source,
    this.brand,
    this.gtin,
    this.carbsPer100g,
    this.fatPer100g,
    this.proteinPer100g,
    this.servingSizeG,
  });

  final String name;
  final String? brand;
  final String? gtin;

  /// Per-100 g macros (null when the source doesn't have them).
  final double? carbsPer100g;
  final double? fatPer100g;
  final double? proteinPer100g;

  /// The product's serving size in grams, when the source provides it.
  final double? servingSizeG;

  /// Where this came from (for display + attribution).
  final String source;

  bool get hasCarbs => carbsPer100g != null;

  String get displayName =>
      (brand != null && brand!.isNotEmpty) ? '$name · $brand' : name;

  double? _for(double? per100, double grams) =>
      per100 == null ? null : per100 * grams / 100.0;

  double? carbsForGrams(double grams) => _for(carbsPer100g, grams);
  double? fatForGrams(double grams) => _for(fatPer100g, grams);
  double? proteinForGrams(double grams) => _for(proteinPer100g, grams);
}
