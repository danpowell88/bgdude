/// Optional small-LLM normaliser for nutrition-panel OCR text.
///
/// The deterministic [NutritionPanelParser] handles standard AU/US layouts. When it can't
/// (foreign-language labels, unusual layouts, OCR that merged the columns), a small
/// on-device text LLM re-reads the OCR text and returns structured fields. The model runs
/// on-device (privacy) and is optional — the app degrades to parser-only until a model is
/// downloaded, so nothing here is on the critical path.
///
/// This file holds the interface plus the *pure* prompt-building and JSON-parsing logic
/// (host-testable). The concrete on-device runner lives in `panel_llm_gemma.dart`.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'nutrition_panel.dart';

abstract interface class PanelLlmExtractor {
  /// Whether a model is loaded and ready. When false, callers skip the LLM path.
  bool get available;

  /// Extract structured nutrition from raw OCR [ocrText], or null if it can't.
  Future<PanelNutrition?> extract(String ocrText);
}

/// Default: no model — the app is parser-only until one is downloaded.
class NoopPanelLlm implements PanelLlmExtractor {
  const NoopPanelLlm();
  @override
  bool get available => false;
  @override
  Future<PanelNutrition?> extract(String ocrText) async => null;
}

/// The instruction we give the LLM. Constrained to JSON-only so the response is parseable
/// and the model can't editorialise numbers into the meal.
String buildPanelPrompt(String ocrText) => '''
You read the OCR text of a food nutrition label and output ONLY a JSON object (no prose,
no markdown). Units: grams for carbs/sugars/fat/protein/fibre, milligrams for sodium,
kilojoules for energy. Give per_serve and per_100g where the label shows them, else null.
Do not guess values that are not in the text; use null.

Output schema:
{"serving_size_g":number|null,"servings_per_package":number|null,
"carbs":{"per_serve":number|null,"per_100g":number|null},
"sugars":{"per_serve":number|null,"per_100g":number|null},
"fat":{"per_serve":number|null,"per_100g":number|null},
"protein":{"per_serve":number|null,"per_100g":number|null},
"energy_kj":{"per_serve":number|null,"per_100g":number|null},
"sodium_mg":{"per_serve":number|null,"per_100g":number|null},
"fibre":{"per_serve":number|null,"per_100g":number|null}}

OCR text:
"""
$ocrText
"""
JSON:''';

/// Parse the LLM's response into a [PanelNutrition]. Tolerant of surrounding prose/markdown
/// (extracts the outermost {...}) and of scalars where an object was expected. Returns null
/// if no usable macro (carbs/fat/protein) came back.
PanelNutrition? parsePanelLlmJson(String response, {String rawText = ''}) {
  final jsonStr = _extractJsonObject(response);
  if (jsonStr == null) return null;
  Map<String, dynamic> m;
  try {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map) return null;
    m = decoded.cast<String, dynamic>();
  } catch (_) {
    return null;
  }

  PanelValue pv(String key) {
    final o = m[key];
    if (o is Map) {
      return PanelValue(perServe: _num(o['per_serve']), per100g: _num(o['per_100g']));
    }
    if (o is num || o is String) {
      // Tolerate a bare scalar — treat it as per-100 g.
      return PanelValue(per100g: _num(o));
    }
    return const PanelValue();
  }

  final raw = PanelNutrition(
    servingSizeG: _num(m['serving_size_g']),
    servingsPerPackage: _num(m['servings_per_package']),
    carbs: pv('carbs'),
    sugars: pv('sugars'),
    fat: pv('fat'),
    protein: pv('protein'),
    energyKj: pv('energy_kj'),
    sodiumMg: pv('sodium_mg'),
    fibre: pv('fibre'),
    rawText: rawText,
    source: 'Label scan (AI)',
  );
  // 5-1 (hard bounds + cross-field) and 5-2 (OCR grounding): an on-device LLM can
  // return numbers that aren't on the label; these drive carb dosing, so scrub before use.
  final panel = validatePanel(raw, rawText);
  if (panel.carbs.isEmpty && panel.fat.isEmpty && panel.protein.isEmpty) {
    return null;
  }
  return panel;
}

/// Extract every numeric token from OCR/label text (comma or dot decimals).
List<double> _numbersIn(String text) => RegExp(r'\d+(?:[.,]\d+)?')
    .allMatches(text)
    .map((mm) => double.tryParse(mm.group(0)!.replaceAll(',', '.')))
    .whereType<double>()
    .toList();

/// Validate a parsed panel (5-1) and ground it against the label text (5-2). Returns a
/// copy with implausible or ungrounded values nulled. Pure and model-agnostic (given the
/// raw text), so it applies to any source, not just the LLM.
PanelNutrition validatePanel(PanelNutrition p, String rawText) {
  final nums = _numbersIn(rawText);

  // 5-2 grounding: keep a value only if a matching number appears in the label text
  // (± comma / rounding). Skipped when there's no text to check against.
  bool grounded(double v) =>
      nums.isEmpty ||
      nums.any((n) => (n - v).abs() <= 0.1 || n.round() == v.round());

  double? ok(double? v, {required double lo, required double hi}) {
    if (v == null || v.isNaN || v < lo || v > hi) return null; // 5-1 hard bounds
    if (!grounded(v)) return null; // 5-2 grounding
    return v;
  }

  final servingSizeG = ok(p.servingSizeG, lo: 1, hi: 1000);

  // 5-1 per-serve consistency: if both scales + a serving size are present but disagree
  // by >25%, the per-serve figure is untrustworthy — drop it, keep per-100g + serving.
  PanelValue val(PanelValue x, {required double per100Max, required double serveMax}) {
    final per100 = ok(x.per100g, lo: 0, hi: per100Max);
    var serve = ok(x.perServe, lo: 0, hi: serveMax);
    if (per100 != null && serve != null && servingSizeG != null) {
      final expected = per100 * servingSizeG / 100.0;
      final denom = math.max(serve.abs(), expected.abs());
      if (denom > 0 && (serve - expected).abs() / denom > 0.25) serve = null;
    }
    return PanelValue(perServe: serve, per100g: per100);
  }

  final carbs = val(p.carbs, per100Max: 100, serveMax: 1000);
  var sugars = val(p.sugars, per100Max: 100, serveMax: 1000);
  final fat = val(p.fat, per100Max: 100, serveMax: 1000);
  final protein = val(p.protein, per100Max: 100, serveMax: 1000);
  final fibre = val(p.fibre, per100Max: 100, serveMax: 1000);
  final energy = val(p.energyKj, per100Max: 4000, serveMax: 20000);
  final sodium = val(p.sodiumMg, per100Max: 5000, serveMax: 5000);

  // 5-1 cross-field: sugars can never exceed carbs (per matching scale). Drop the
  // implausible sugar value rather than trust it.
  double? capSugar(double? s, double? c) =>
      (s != null && c != null && s > c + 1e-6) ? null : s;
  sugars = PanelValue(
    perServe: capSugar(sugars.perServe, carbs.perServe),
    per100g: capSugar(sugars.per100g, carbs.per100g),
  );

  return PanelNutrition(
    servingSizeG: servingSizeG,
    servingsPerPackage: ok(p.servingsPerPackage, lo: 1, hi: 100),
    carbs: carbs,
    sugars: sugars,
    fat: fat,
    protein: protein,
    energyKj: energy,
    sodiumMg: sodium,
    fibre: fibre,
    rawText: p.rawText,
    source: p.source,
  );
}

double? _num(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
  return null;
}

String? _extractJsonObject(String s) {
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  return s.substring(start, end + 1);
}
