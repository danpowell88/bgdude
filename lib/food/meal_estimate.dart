/// Free-text meal → macros (issue #79).
///
/// Type "chicken burrito and a small chips" and get an itemised carb/fat/protein
/// estimate, instead of looking each item up by hand. Everything here is pure — prompt
/// construction, JSON parsing and validation — so the behaviour that matters is testable
/// without an on-device model.
///
/// This is an **estimate**, and the UI is required to say so and stay editable. It is
/// nobody's dose calculation until the user has looked at it.
library;

import 'dart:convert';

/// One dish in an estimated meal.
class MealEstimateItem {
  const MealEstimateItem({
    required this.name,
    this.grams,
    this.carbsG,
    this.fatG,
    this.proteinG,
  });

  final String name;

  /// Estimated portion weight, when the model offered one.
  final double? grams;
  final double? carbsG;
  final double? fatG;
  final double? proteinG;

  MealEstimateItem copyWith({
    double? grams,
    double? carbsG,
    double? fatG,
    double? proteinG,
  }) =>
      MealEstimateItem(
        name: name,
        grams: grams ?? this.grams,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
        proteinG: proteinG ?? this.proteinG,
      );
}

/// Where an estimate came from — shown to the user, because an on-device model's guess
/// and a food-database lookup deserve different amounts of trust.
enum MealEstimateSource {
  /// The on-device language model.
  model,

  /// Name search against the bundled Australian food database.
  foodDatabase,
}

/// An itemised estimate for a typed meal description.
class MealEstimate {
  const MealEstimate({required this.items, required this.source});

  final List<MealEstimateItem> items;
  final MealEstimateSource source;

  bool get isEmpty => items.isEmpty;

  double get totalCarbsG => _sum((i) => i.carbsG);
  double get totalFatG => _sum((i) => i.fatG);
  double get totalProteinG => _sum((i) => i.proteinG);

  double _sum(double? Function(MealEstimateItem) pick) =>
      items.fold(0, (a, i) => a + (pick(i) ?? 0));
}

/// The instruction given to the on-device model. JSON-only so the response is
/// parseable and the model can't editorialise numbers into the meal.
String buildMealEstimatePrompt(String description) => '''
You estimate the nutrition of a described meal and output ONLY a JSON object (no prose,
no markdown, no code fences).

Split the description into individual dishes. For each, estimate a typical portion in
grams and its carbohydrate, fat and protein in grams for THAT portion. If a quantity is
given ("2 tacos", "large coffee"), estimate for that quantity. Use null when you cannot
estimate a field; never guess a number you have no basis for.

Format:
{"items":[{"name":"chicken burrito","grams":300,"carbs_g":65,"fat_g":18,"protein_g":30}]}

Meal: $description
''';

/// Parses the model's response into an estimate.
///
/// Tolerates the model wrapping JSON in prose or a code fence, which small on-device
/// models do routinely despite being told not to. Returns null when nothing usable
/// comes back, so the caller can fall back rather than show an empty result.
MealEstimate? parseMealEstimateJson(String response) {
  final json = _firstJsonObject(response);
  if (json == null) return null;

  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;

  final rawItems = decoded['items'];
  if (rawItems is! List) return null;

  final items = <MealEstimateItem>[];
  for (final raw in rawItems) {
    if (raw is! Map) continue;
    final name = (raw['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;
    items.add(MealEstimateItem(
      name: name,
      grams: _num(raw['grams']),
      carbsG: _num(raw['carbs_g']),
      fatG: _num(raw['fat_g']),
      proteinG: _num(raw['protein_g']),
    ));
  }
  if (items.isEmpty) return null;
  return MealEstimate(items: items, source: MealEstimateSource.model);
}

/// Applies plausibility bounds to an estimate, nulling values that can't be right.
///
/// **Deliberately does NOT apply the label scanner's numeric grounding.** That check
/// keeps a value only when the same number appears in the source text, which is right
/// for a nutrition label — the numbers are printed on it. A meal description is the
/// opposite case: any numbers in it are quantities ("2 tacos", "500ml coke"), not
/// macros, so requiring the estimated carbs to match them would null nearly everything
/// and quietly make the feature useless. Bounds are the check that transfers; grounding
/// is not.
MealEstimate validateMealEstimate(MealEstimate estimate) {
  double? bounded(double? v, double max) {
    if (v == null || v.isNaN || v.isInfinite || v < 0 || v > max) return null;
    return v;
  }

  final items = <MealEstimateItem>[];
  for (final item in estimate.items) {
    final grams = bounded(item.grams, 5000);
    var carbs = bounded(item.carbsG, 1000);
    var fat = bounded(item.fatG, 1000);
    var protein = bounded(item.proteinG, 1000);

    // A macro can never exceed the portion it came from. Catches an order-of-magnitude
    // slip (65 g of carbs claimed in a 30 g biscuit) that bare bounds would let past —
    // and that would read as a plausible dose.
    if (grams != null) {
      if (carbs != null && carbs > grams) carbs = null;
      if (fat != null && fat > grams) fat = null;
      if (protein != null && protein > grams) protein = null;
    }

    items.add(MealEstimateItem(
      name: item.name,
      grams: grams,
      carbsG: carbs,
      fatG: fat,
      proteinG: protein,
    ));
  }
  return MealEstimate(items: items, source: estimate.source);
}

/// Splits a typed description into individual dish phrases, for the no-model fallback.
///
/// Handles the separators people actually type. Kept pure and separate so the fallback's
/// behaviour is testable without a food database.
List<String> splitMealDescription(String description) {
  final parts = description
      .split(RegExp(r',|\band\b|\bwith\b|\+|\n', caseSensitive: false))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  return parts;
}

/// The first balanced `{...}` block in [text], or null.
///
/// Scans for balance rather than taking the first `{` to the last `}`: a model that
/// emits two objects, or trailing commentary containing a brace, would otherwise
/// produce a string that fails to parse and lose an otherwise-good answer.
String? _firstJsonObject(String text) {
  final start = text.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < text.length; i++) {
    final c = text[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (c == r'\') {
      escaped = true;
      continue;
    }
    if (c == '"') inString = !inString;
    if (inString) continue;
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return text.substring(start, i + 1);
    }
  }
  return null;
}

double? _num(Object? v) => switch (v) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s.trim()),
      _ => null,
    };
