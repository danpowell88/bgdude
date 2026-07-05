/// Orchestrates reading a nutrition panel from a photo: OCR → deterministic parse → (only
/// when needed and available) small-LLM normalise. The deterministic parser is preferred
/// because its numbers are auditable against the OCR text; the LLM is a fallback for
/// layouts/languages it can't handle.
library;

import 'nutrition_panel.dart';
import 'nutrition_panel_parser.dart';
import 'panel_llm.dart';
import 'panel_ocr.dart';

class PanelScanResult {
  const PanelScanResult({
    required this.ocrText,
    this.panel,
    this.usedLlm = false,
  });

  /// Raw OCR text (shown on the confirm screen so the user can sanity-check).
  final String ocrText;

  /// Extracted nutrition, or null when neither the parser nor the LLM found anything.
  final PanelNutrition? panel;

  /// Whether the LLM normaliser produced this result (vs the deterministic parser).
  final bool usedLlm;

  bool get hasResult => panel != null;
}

class PanelScanService {
  PanelScanService({
    required this.ocr,
    PanelLlmExtractor? llm,
    NutritionPanelParser parser = const NutritionPanelParser(),
  })  : llm = llm ?? const NoopPanelLlm(),
        _parser = parser;

  final PanelOcr ocr;
  final PanelLlmExtractor llm;
  final NutritionPanelParser _parser;

  /// Confidence below which we try the LLM (if a deterministic result even exists).
  static const double _llmThreshold = 0.6;

  Future<PanelScanResult> scan(String imagePath) async {
    final text = await ocr.readText(imagePath);
    if (text.trim().isEmpty) return PanelScanResult(ocrText: text);

    final deterministic = _parser.parse(text);
    final goodEnough =
        deterministic != null && deterministic.confidence >= _llmThreshold;

    if (!goodEnough && llm.available) {
      try {
        final ai = await llm.extract(text);
        if (ai != null &&
            (deterministic == null ||
                ai.confidence > deterministic.confidence)) {
          return PanelScanResult(
            ocrText: text,
            panel: ai.copyWith(rawText: text),
            usedLlm: true,
          );
        }
      } catch (_) {
        // Fall through to whatever the parser managed.
      }
    }
    return PanelScanResult(ocrText: text, panel: deterministic);
  }
}
