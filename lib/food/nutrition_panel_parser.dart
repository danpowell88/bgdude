/// Deterministic parser that turns OCR text of a nutrition panel into [PanelNutrition].
///
/// Handles the two layouts a photo is most likely to contain:
///  * **AU/NZ Nutrition Information Panel** — two columns ("Per Serve" and "Per 100 g"),
///    each nutrient row carrying two numbers.
///  * **US Nutrition Facts** — a single per-serving column.
///
/// It is intentionally regex/heuristic (no ML): the panel is standardised text, so a
/// deterministic pass is small, fast, offline, and — unlike a generative model — can't
/// invent a carb number. When it can't find the fields that matter, the caller falls back
/// to the LLM normaliser. Everything it extracts is shown for the user to confirm.
library;

import 'nutrition_panel.dart';

class NutritionPanelParser {
  const NutritionPanelParser();

  static final _numUnit = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(mg|mcg|µg|kj|kcal|cal|g)?',
      caseSensitive: false);
  static final _gramsBeforeG =
      RegExp(r'(\d+(?:[.,]\d+)?)\s*g', caseSensitive: false);
  static final _int = RegExp(r'(\d+)');

  PanelNutrition? parse(String ocrText) {
    if (ocrText.trim().isEmpty) return null;
    final lines = ocrText
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final lower = ocrText.toLowerCase();

    // Two-column when the label prints a "per 100 g/ml" header alongside a per-serve one.
    final twoColumn = RegExp(r'per\s*100\s*(g|ml)').hasMatch(lower);

    String? lineWith(bool Function(String lower) test) {
      for (final l in lines) {
        if (test(l.toLowerCase())) return l;
      }
      return null;
    }

    PanelValue grams(String? line) => _value(line, twoColumn, _kGram);
    PanelValue energy(String? line) => _value(line, twoColumn, _kEnergy);
    PanelValue sodium(String? line) => _value(line, twoColumn, _kSodium);

    final carbsLine = lineWith((l) => l.contains('carbohydrate') || l.contains('carbs'));
    final sugarsLine = lineWith((l) => l.contains('sugar'));
    // "Fat, total" / "Total Fat" but NOT the "saturated" sub-row.
    final fatLine =
        lineWith((l) => l.contains('fat') && !l.contains('satur'));
    final proteinLine = lineWith((l) => l.contains('protein'));
    final energyLine = lineWith((l) => l.contains('energy'));
    final sodiumLine =
        lineWith((l) => l.contains('sodium') || l.contains('salt'));
    final fibreLine =
        lineWith((l) => l.contains('fibre') || l.contains('fiber'));

    final panel = PanelNutrition(
      servingSizeG: _servingSize(lineWith(
          (l) => l.contains('serving size') || l.contains('serve size'))),
      servingsPerPackage: _servings(lineWith((l) =>
          (l.contains('servings') || l.contains('serving')) &&
          (l.contains('per pack') ||
              l.contains('per container') ||
              l.contains('perpackage')))),
      carbs: grams(carbsLine),
      sugars: grams(sugarsLine),
      fat: grams(fatLine),
      protein: grams(proteinLine),
      energyKj: energy(energyLine),
      sodiumMg: sodium(sodiumLine),
      fibre: grams(fibreLine),
      rawText: ocrText,
      source: 'Label scan',
    );

    // Nothing usable at all → let the caller try the LLM.
    if (panel.carbs.isEmpty &&
        panel.protein.isEmpty &&
        panel.fat.isEmpty &&
        panel.energyKj.isEmpty) {
      return null;
    }
    return panel;
  }

  // Which units count for a given nutrient family.
  static const _kGram = {'g', ''};
  static const _kEnergy = {'kj', 'kcal', 'cal'};
  static const _kSodium = {'mg'};

  /// Pull the (perServe, per100g) numbers off a nutrient line, keeping only tokens whose
  /// unit belongs to [units]. For a single-column (US) label the lone number is per-serve.
  PanelValue _value(String? line, bool twoColumn, Set<String> units) {
    if (line == null) return const PanelValue();
    final vals = <double>[];
    for (final m in _numUnit.allMatches(line)) {
      final unit = (m.group(2) ?? '').toLowerCase();
      if (!units.contains(unit)) continue;
      final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      if (v != null) vals.add(v);
    }
    if (vals.isEmpty) return const PanelValue();
    if (!twoColumn) return PanelValue(perServe: vals.first);
    if (vals.length == 1) {
      // Ambiguous single value on a two-column label → treat as the per-100 g column (the
      // standardising one), which [PanelValue.per100gOr] can use directly.
      return PanelValue(per100g: vals.first);
    }
    return PanelValue(perServe: vals[0], per100g: vals[1]);
  }

  double? _servingSize(String? line) {
    if (line == null) return null;
    // Prefer the grams value nearest the end (e.g. US "2/3 cup (55g)").
    double? found;
    for (final m in _gramsBeforeG.allMatches(line)) {
      found = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    }
    return found;
  }

  double? _servings(String? line) {
    if (line == null) return null;
    final m = _int.firstMatch(line);
    return m == null ? null : double.tryParse(m.group(1)!);
  }
}
