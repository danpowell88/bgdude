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

  final panel = PanelNutrition(
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
  if (panel.carbs.isEmpty && panel.fat.isEmpty && panel.protein.isEmpty) {
    return null;
  }
  return panel;
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
