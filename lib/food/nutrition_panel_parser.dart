/// Deterministic parser that turns OCR text of a nutrition panel into [PanelNutrition].
///
/// Handles the common layouts a photo contains:
///  * **AU/NZ / EU two-column** — "Per Serve" and "Per 100 g" columns, two numbers a row.
///  * **US Nutrition Facts** — a single per-serving column.
/// It recognises nutrient names in several languages (English, French, German, Spanish,
/// Italian), since off-the-shelf products are often labelled in the local language, and
/// falls back to the next line for the numbers when OCR puts the value under its label.
///
/// It's intentionally regex/heuristic (no ML): the panel is standardised text, so a
/// deterministic pass is small, fast, offline, and — unlike a generative model — can't
/// invent a carb number. When it can't find the fields that matter (foreign layouts, OCR
/// that scattered the columns), the caller falls back to the LLM normaliser. Everything it
/// extracts is shown for the user to confirm.
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

  // Nutrient names across common label languages (substring match, lower-cased).
  static const _carbWords = [
    'carbohydrate', 'carbs', 'glucides', 'kohlenhydrate', 'carboidrati',
    'hidratos', 'koolhydraten',
  ];
  static const _fatWords = [
    'fat', 'matières grasses', 'matieres grasses', 'lipides', 'fett', 'grassi',
    'grasas', 'lípidos', 'lipidos', 'vetten',
  ];
  static const _saturatedWords = [
    'satur', 'gesätt', 'gesatt', 'verzadig',
  ];
  static const _proteinWords = [
    'protein', 'protéines', 'proteines', 'eiweiß', 'eiweiss', 'proteine',
    'proteínas', 'proteinas', 'eiwitten',
  ];
  static const _sugarWords = [
    'sugar', 'sucres', 'zucker', 'zuccheri', 'azúcares', 'azucares', 'suikers',
  ];
  static const _sodiumWords = [
    'sodium', 'salt', 'sel', 'salz', 'sale', 'sal', 'zout',
  ];
  static const _energyWords = [
    'energy', 'énergie', 'energie', 'energia', 'energía',
  ];
  static const _fibreWords = [
    'fibre', 'fiber', 'ballaststoffe', 'fibra', 'vezels',
  ];

  PanelNutrition? parse(String ocrText) {
    if (ocrText.trim().isEmpty) return null;
    final lines = ocrText
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final lower = ocrText.toLowerCase();

    // Two-column when the label prints a "per 100 g/ml" header.
    final twoColumn = RegExp(r'per\s*100\s*(g|ml)').hasMatch(lower) ||
        RegExp(r'pour\s*100\s*(g|ml)').hasMatch(lower) ||
        RegExp(r'pro\s*100\s*(g|ml)').hasMatch(lower);

    /// Index of the first line containing any of [words] (and, for fat, none of the
    /// saturated words).
    int indexWith(List<String> words, {List<String> exclude = const []}) {
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i].toLowerCase();
        if (words.any(l.contains) && !exclude.any(l.contains)) return i;
      }
      return -1;
    }

    PanelValue grams(List<String> w, {List<String> exclude = const []}) =>
        _value(lines, indexWith(w, exclude: exclude), twoColumn, _kGram);

    final panel = PanelNutrition(
      servingSizeG: _servingSize(lines, indexWith(const [
        'serving size', 'serve size', 'portion', 'portione', 'dose',
      ])),
      servingsPerPackage: _servings(lines, _servingsIndex(lines)),
      carbs: grams(_carbWords),
      sugars: grams(_sugarWords),
      fat: grams(_fatWords, exclude: _saturatedWords),
      protein: grams(_proteinWords),
      energyKj: _value(lines, indexWith(_energyWords), twoColumn, _kEnergy),
      sodiumMg: _value(lines, indexWith(_sodiumWords), twoColumn, _kSodium),
      fibre: grams(_fibreWords),
      rawText: ocrText,
      source: 'Label scan',
    );

    if (panel.carbs.isEmpty &&
        panel.protein.isEmpty &&
        panel.fat.isEmpty &&
        panel.energyKj.isEmpty) {
      return null; // nothing usable → let the caller try the LLM
    }
    return panel;
  }

  static const _kGram = {'g', ''};
  static const _kEnergy = {'kj', 'kcal', 'cal'};
  static const _kSodium = {'mg'};

  /// Pull (perServe, per100g) numbers for the nutrient at [index], keeping only tokens
  /// whose unit is in [units]. If the label line has no numbers (OCR often puts the value
  /// on the next line), look one line ahead. A lone number on a two-column label is treated
  /// as the standardising per-100 g column.
  PanelValue _value(
      List<String> lines, int index, bool twoColumn, Set<String> units) {
    if (index < 0) return const PanelValue();
    var vals = _numbersOn(lines[index], units);
    if (vals.isEmpty && index + 1 < lines.length) {
      // Follow-line fallback: value printed under its label. Guard against grabbing the
      // *next* nutrient's line by only doing this when that line has no letters-as-label.
      final next = lines[index + 1];
      if (!_looksLikeLabel(next)) vals = _numbersOn(next, units);
    }
    if (vals.isEmpty) return const PanelValue();
    if (!twoColumn) return PanelValue(perServe: vals.first);
    if (vals.length == 1) return PanelValue(per100g: vals.first);
    return PanelValue(perServe: vals[0], per100g: vals[1]);
  }

  List<double> _numbersOn(String line, Set<String> units) {
    final out = <double>[];
    for (final m in _numUnit.allMatches(line)) {
      final unit = (m.group(2) ?? '').toLowerCase();
      if (!units.contains(unit)) continue;
      final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      if (v != null) out.add(v);
    }
    return out;
  }

  /// A line that is mostly a word (a nutrient label) rather than numbers — used to avoid
  /// the follow-line fallback swallowing the next label row.
  bool _looksLikeLabel(String line) {
    final letters = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(line).length;
    final digits = RegExp(r'\d').allMatches(line).length;
    return letters > 3 && digits == 0;
  }

  int _servingsIndex(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i].toLowerCase();
      final isServings = l.contains('servings') || l.contains('serving') ||
          l.contains('portions') || l.contains('portionen');
      final perPack = l.contains('per pack') ||
          l.contains('per container') ||
          l.contains('perpackage') ||
          l.contains('par paquet') ||
          l.contains('pro packung');
      if (isServings && perPack) return i;
    }
    return -1;
  }

  double? _servingSize(List<String> lines, int index) {
    if (index < 0) return null;
    // Prefer the grams value nearest the end (e.g. US "2/3 cup (55g)").
    double? found;
    for (final m in _gramsBeforeG.allMatches(lines[index])) {
      found = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    }
    return found;
  }

  double? _servings(List<String> lines, int index) {
    if (index < 0) return null;
    final m = _int.firstMatch(lines[index]);
    return m == null ? null : double.tryParse(m.group(1)!);
  }
}
