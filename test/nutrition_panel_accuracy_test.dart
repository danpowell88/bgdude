import 'dart:convert';
import 'dart:io';

import 'package:bgdude/food/nutrition_panel_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Accuracy harness for the nutrition-panel parser, scored against **real product values**
/// pulled from Open Food Facts (test/data/nutrition_panels.json — 100 products).
///
/// What this measures: the deterministic text→values parser across many real-world value
/// profiles rendered in several label layouts (AU two-column, US Nutrition Facts, EU
/// per-100 g, comma decimals). Device OCR can't run in a host unit test, so the panel text
/// is rendered from each product's ground-truth values as a stand-in for OCR output; the
/// dataset keeps each product's URL so the *full* image→values pipeline (ML Kit OCR + the
/// parser) can be scored on-device in integration_test/ against the actual label photos.
void main() {
  final raw = File('test/data/nutrition_panels.json').readAsStringSync();
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final panels = (data['panels'] as List).cast<Map<String, dynamic>>();
  const parser = NutritionPanelParser();

  test('dataset is the expected size', () {
    expect(panels.length, 100);
  });

  test('parser accuracy across 100 real Open Food Facts panels', () {
    var carbsTotal = 0, carbsHit = 0;
    var fatTotal = 0, fatHit = 0;
    var protTotal = 0, protHit = 0;
    var servingTotal = 0, servingHit = 0;
    var parsedTotal = 0;

    // Correct if within 3% of the value, or 1 g/unit absolute for small values.
    bool near(double got, double want) =>
        (got - want).abs() <= (want.abs() * 0.03).clamp(1.0, double.infinity);

    for (var i = 0; i < panels.length; i++) {
      final p = panels[i];
      final per100 = (p['per100g'] as Map).cast<String, dynamic>();
      final serving = (p['servingSizeG'] as num?)?.toDouble();
      final carbs100 = (per100['carbs'] as num).toDouble();
      final fat100 = (per100['fat'] as num?)?.toDouble();
      final prot100 = (per100['protein'] as num?)?.toDouble();

      // Layout by index (EU per-100 g layout has no serving line, like the real labels).
      final layout = serving == null ? 2 : i % 3;
      final text = _renderPanel(i, layout, per100, serving);
      final parsed = parser.parse(text);
      if (parsed == null) continue;
      parsedTotal++;
      final item = parsed.toFoodItem(name: p['name'] as String?);

      carbsTotal++;
      if (item.carbsPer100g != null && near(item.carbsPer100g!, carbs100)) {
        carbsHit++;
      }
      if (fat100 != null) {
        fatTotal++;
        if (item.fatPer100g != null && near(item.fatPer100g!, fat100)) fatHit++;
      }
      if (prot100 != null) {
        protTotal++;
        if (item.proteinPer100g != null && near(item.proteinPer100g!, prot100)) {
          protHit++;
        }
      }
      // Only score serving size on layouts that actually print it.
      if (serving != null && serving > 0 && layout != 2) {
        servingTotal++;
        if (parsed.servingSizeG != null && near(parsed.servingSizeG!, serving)) {
          servingHit++;
        }
      }
    }

    double pct(int hit, int total) => total == 0 ? 0 : hit / total;
    final report = StringBuffer()
      ..writeln('Nutrition-panel parser accuracy (100 real OFF products):')
      ..writeln('  parsed:  $parsedTotal / ${panels.length}')
      ..writeln('  carbs:   $carbsHit / $carbsTotal '
          '(${(pct(carbsHit, carbsTotal) * 100).toStringAsFixed(1)}%)')
      ..writeln('  fat:     $fatHit / $fatTotal '
          '(${(pct(fatHit, fatTotal) * 100).toStringAsFixed(1)}%)')
      ..writeln('  protein: $protHit / $protTotal '
          '(${(pct(protHit, protTotal) * 100).toStringAsFixed(1)}%)')
      ..writeln('  serving: $servingHit / $servingTotal '
          '(${(pct(servingHit, servingTotal) * 100).toStringAsFixed(1)}%)');
    // ignore: avoid_print
    print(report);

    // Regression gates. Carbs is the field the app depends on, so it must be high.
    expect(parsedTotal, greaterThanOrEqualTo(95),
        reason: 'parser should extract something from nearly every panel');
    expect(pct(carbsHit, carbsTotal), greaterThanOrEqualTo(0.9),
        reason: 'carbohydrate accuracy');
    expect(pct(fatHit, fatTotal), greaterThanOrEqualTo(0.85),
        reason: 'fat accuracy');
    expect(pct(protHit, protTotal), greaterThanOrEqualTo(0.85),
        reason: 'protein accuracy');
    expect(pct(servingHit, servingTotal), greaterThanOrEqualTo(0.85),
        reason: 'serving-size accuracy');
  });
}

/// Render a nutrition-panel text from ground-truth values, choosing a layout by index so
/// the corpus exercises the AU/US/EU variants and comma decimals.
String _renderPanel(
    int i, int layout, Map<String, dynamic> per100, double? serving) {
  final comma = i % 3 == 0; // some locales use ',' as the decimal separator
  String n(num? v, {int dp = 1}) {
    if (v == null) return '';
    final s = v.toStringAsFixed(dp);
    return comma ? s.replaceAll('.', ',') : s;
  }

  double? g(String k) => (per100[k] as num?)?.toDouble();
  final c = g('carbs'), f = g('fat'), pr = g('protein');
  final sg = g('sugars'), e = g('energyKj'), na = g('sodiumMg'), fb = g('fibre');

  // Per-serve values derived from per-100 g (only when we have a serving size).
  double? perServe(double? per) =>
      (per == null || serving == null) ? null : per * serving / 100.0;

  if (layout == 0) {
    // AU/NZ two-column NIP.
    final b = StringBuffer()
      ..writeln('NUTRITION INFORMATION')
      ..writeln('Servings per package: 10')
      ..writeln('Serving size: ${n(serving, dp: 0)}g')
      ..writeln('              Per Serve   Per 100g');
    void row(String label, double? per, String unit) {
      if (per == null) return;
      b.writeln('$label   ${n(perServe(per))}$unit   ${n(per)}$unit');
    }
    row('Energy', e, 'kJ');
    row('Protein', pr, 'g');
    row('Fat, total', f, 'g');
    row('Carbohydrate', c, 'g');
    if (sg != null) row('- sugars', sg, 'g');
    if (fb != null) row('Dietary fibre', fb, 'g');
    row('Sodium', na, 'mg');
    return b.toString();
  }
  if (layout == 1) {
    // US Nutrition Facts (single per-serving column).
    final b = StringBuffer()
      ..writeln('Nutrition Facts')
      ..writeln('About 10 servings per container')
      ..writeln('Serving size (${n(serving, dp: 0)}g)')
      ..writeln('Amount per serving');
    void row(String label, double? per, String unit) {
      final v = perServe(per);
      if (v == null) return;
      b.writeln('$label ${n(v)}$unit');
    }
    row('Total Fat', f, 'g');
    row('Total Carbohydrate', c, 'g');
    if (sg != null) row('Total Sugars', sg, 'g');
    row('Protein', pr, 'g');
    row('Sodium', na, 'mg');
    return b.toString();
  }
  // EU per-100 g only.
  final b = StringBuffer()
    ..writeln('Nutrition')
    ..writeln('Per 100 g');
  if (e != null) b.writeln('Energy ${n(e)} kJ');
  if (f != null) b.writeln('Fat ${n(f)} g');
  if (c != null) b.writeln('Carbohydrate ${n(c)} g');
  if (sg != null) b.writeln('of which sugars ${n(sg)} g');
  if (pr != null) b.writeln('Protein ${n(pr)} g');
  return b.toString();
}
