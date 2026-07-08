import 'package:bgdude/food/nutrition_panel_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = NutritionPanelParser();

  test('AU two-column NIP: carbs/serving and both columns', () {
    const text = '''
NUTRITION INFORMATION
Servings per package: 12
Serving size: 30g (2 biscuits)
              Per Serve   Per 100g
Energy        462kJ       1540kJ
Protein       3.4g        11.3g
Fat, total    0.4g        1.3g
- saturated   0.1g        0.3g
Carbohydrate  19.2g       64.0g
- sugars      1.0g        3.3g
Dietary fibre 3.2g        10.7g
Sodium        85mg        283mg
''';
    final p = parser.parse(text)!;
    expect(p.servingSizeG, 30);
    expect(p.servingsPerPackage, 12);
    expect(p.carbs.perServe, closeTo(19.2, 0.01));
    expect(p.carbs.per100g, closeTo(64.0, 0.01));
    expect(p.sugars.per100g, closeTo(3.3, 0.01));
    // Fat, total — not the "saturated" sub-row.
    expect(p.fat.perServe, closeTo(0.4, 0.01));
    expect(p.protein.per100g, closeTo(11.3, 0.01));
    expect(p.energyKj.per100g, closeTo(1540, 0.5));
    expect(p.sodiumMg.per100g, closeTo(283, 0.5));
    expect(p.hasCarbs, isTrue);
  });

  test('US Nutrition Facts: single per-serving column, grams in parens', () {
    const text = '''
Nutrition Facts
8 servings per container
Serving size 2/3 cup (55g)
Amount per serving
Calories 230
Total Fat 8g
Saturated Fat 1g
Total Carbohydrate 37g
Dietary Fiber 4g
Total Sugars 12g
Protein 3g
Sodium 160mg
''';
    final p = parser.parse(text)!;
    expect(p.servingSizeG, 55);
    expect(p.servingsPerPackage, 8);
    expect(p.carbs.perServe, closeTo(37, 0.01));
    expect(p.carbs.per100g, isNull); // single column
    expect(p.fat.perServe, closeTo(8, 0.01));
    expect(p.protein.perServe, closeTo(3, 0.01));
    expect(p.sugars.perServe, closeTo(12, 0.01));
    expect(p.sodiumMg.perServe, closeTo(160, 0.5));

    // per-100 g derives from serving size for the FoodItem.
    final item = p.toFoodItem(name: 'Cereal');
    expect(item.carbsPer100g, closeTo(37 / 55 * 100, 0.1));
    expect(item.servingSizeG, 55);
  });

  test('comma-decimal, single per-100 g column', () {
    const text = '''
Nutrition
Per 100 g
Energy 1540 kJ
Fat 1,3 g
Carbohydrate 64,0 g
of which sugars 3,3 g
Protein 11,3 g
Salt 0,72 g
''';
    final p = parser.parse(text)!;
    expect(p.carbs.per100g, closeTo(64.0, 0.01));
    expect(p.fat.per100g, closeTo(1.3, 0.01));
    expect(p.protein.per100g, closeTo(11.3, 0.01));
    expect(p.sugars.per100g, closeTo(3.3, 0.01));
  });

  test('returns null for text with no recognisable nutrients (→ LLM fallback)', () {
    expect(parser.parse('Ingredients: wheat flour, water, salt, yeast.'), isNull);
    expect(parser.parse(''), isNull);
  });

  test('French per-100 g label (Glucides/Lipides/Protéines, comma decimals)', () {
    const text = '''
Valeurs nutritionnelles pour 100 g
Énergie 1540 kJ
Matières grasses 1,3 g
Glucides 64,0 g
dont sucres 3,3 g
Protéines 11,3 g
Sel 0,72 g
''';
    final p = parser.parse(text)!;
    expect(p.carbs.per100g, closeTo(64.0, 0.01));
    expect(p.fat.per100g, closeTo(1.3, 0.01));
    expect(p.protein.per100g, closeTo(11.3, 0.01));
    expect(p.sugars.per100g, closeTo(3.3, 0.01));
  });

  test('German label excludes the "gesättigte" saturated row from fat', () {
    const text = '''
Nährwerte pro 100 g
Fett 12,0 g
davon gesättigte Fettsäuren 4,0 g
Kohlenhydrate 58,0 g
Eiweiß 7,0 g
''';
    final p = parser.parse(text)!;
    expect(p.fat.per100g, closeTo(12.0, 0.01)); // not the 4.0 saturated row
    expect(p.carbs.per100g, closeTo(58.0, 0.01));
    expect(p.protein.per100g, closeTo(7.0, 0.01));
  });

  test('follow-line fallback: value printed under its label', () {
    const text = '''
Nutrition
Carbohydrate
40g
Protein
5g
''';
    final p = parser.parse(text)!;
    expect(p.carbs.perServe, closeTo(40, 0.01));
    expect(p.protein.perServe, closeTo(5, 0.01));
  });

  test('does not confuse the sugars sub-row for carbohydrate', () {
    const text = '''
Per 100g
Carbohydrate 27.0g
- sugars 9.0g
Protein 5.0g
''';
    final p = parser.parse(text)!;
    expect(p.carbs.per100g, closeTo(27.0, 0.01));
    expect(p.sugars.per100g, closeTo(9.0, 0.01));
  });

  test('a %DV column is not read as a macro value', () {
    // US single-column with a Daily Value % after the grams. The 15% must be ignored.
    const text = '''
Nutrition Facts
Serving size 40g
Total Carbohydrate 24g 9%
Protein 5g
Total Fat 3g 4%
''';
    final p = parser.parse(text)!;
    expect(p.carbs.perServe, closeTo(24.0, 0.01)); // 24g, NOT 9%
    expect(p.fat.perServe, closeTo(3.0, 0.01)); // 3g, NOT 4%
  });

  test('an ml serving size is captured', () {
    const text = '''
Nutrition Information
Serving size: 250ml
Carbohydrate 11.0g
''';
    final p = parser.parse(text)!;
    expect(p.servingSizeG, closeTo(250.0, 0.01)); // 1 ml ≈ 1 g
  });

  test('EU salt (grams) is converted to sodium (mg) ×400', () {
    const text = '''
Nutrition (per 100g)
Carbohydrate 60g
Salt 0.5g
''';
    final p = parser.parse(text)!;
    expect(p.sodiumMg.per100g, closeTo(200.0, 0.5)); // 0.5 g salt × 400
  });

  test('combined kJ/kcal energy prefers kJ', () {
    const text = '''
Nutrition (per 100g)
Energy 1200kJ 287kcal
Carbohydrate 60g
''';
    final p = parser.parse(text)!;
    expect(p.energyKj.per100g, closeTo(1200.0, 1.0)); // kJ, not the kcal figure
  });
}
