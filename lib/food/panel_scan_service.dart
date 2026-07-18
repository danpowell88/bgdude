/// Orchestrates reading a nutrition panel from a photo: OCR → deterministic parse → (only
/// when needed and available) small-LLM normalise. The deterministic parser is preferred
/// because its numbers are auditable against the OCR text; the LLM is a fallback for
/// layouts/languages it can't handle.
library;

import '../logging/app_log.dart';
import 'nutrition_panel.dart';
import 'nutrition_panel_parser.dart';
import 'panel_llm.dart';
import 'panel_geometry.dart';
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
  // 5-3: a carbs-only parse scores exactly 0.6 (the old threshold), so ANY carb value —
  // however garbled — used to block the LLM. Require more than a bare carb value (0.7 =
  // carbs + one macro) before the parse is "good enough" to skip the LLM. The LLM result
  // it competes against is already OCR-grounded (5-2), so its confidence counts only
  // grounded fields — a hallucinated-complete panel can no longer beat an honest one.
  static const double _llmThreshold = 0.7;

  /// Row-reconstructed OCR text, or null when this OCR has no geometry (or it failed).
  Future<String?> _reconstructedText(String imagePath) async {
    final source = ocr;
    if (source is! PanelOcrWithGeometry) return null;
    try {
      final lines = await source.readLines(imagePath);
      if (lines.isEmpty) return null;
      final rebuilt = reconstructColumns(lines);
      return rebuilt.trim().isEmpty ? null : rebuilt;
    } catch (e) {
      // Geometry is an optimisation; never let it break a scan that flat text can serve.
      appLog.error('panel_scan', 'column reconstruction failed', error: e);
      return null;
    }
  }

  /// Parses both candidate texts and keeps the better result.
  ///
  /// Ties go to the reconstructed text: when both parse equally well, the row-aligned
  /// version is the one whose per-serve/per-100 g split is actually trustworthy — a flat
  /// parse can score the same having guessed the column order.
  PanelNutrition? _bestParse(String flat, String? rebuilt) {
    final flatParse = _parser.parse(flat);
    if (rebuilt == null) return flatParse;
    final rebuiltParse = _parser.parse(rebuilt);
    if (rebuiltParse == null) return flatParse;
    if (flatParse == null) return rebuiltParse;
    return rebuiltParse.confidence >= flatParse.confidence
        ? rebuiltParse
        : flatParse;
  }

  Future<PanelScanResult> scan(String imagePath) async {
    final String text;
    try {
      // TASK-208: guarded at the source rather than relying on the sole caller's
      // try/catch — a PlatformException from ML Kit (e.g. a corrupt photo file, or a
      // MissingPluginException right after an engine restart) must degrade to "no
      // result" here, not depend on whoever calls scan() to have wrapped it.
      text = await ocr.readText(imagePath);
    } catch (e) {
      appLog.error('panel_scan', 'OCR failed', error: e);
      return const PanelScanResult(ocrText: '');
    }
    if (text.trim().isEmpty) return PanelScanResult(ocrText: text);

    // Issue #104: when the recogniser can give us geometry, try rebuilding the panel's
    // visual rows first. ML Kit often returns one block per COLUMN, so the flat text
    // reads every label, then every per-serve number, then every per-100 g number —
    // which the parser cannot align. Row reconstruction fixes that without the LLM.
    //
    // Kept as a candidate rather than a replacement: reconstruction depends on the
    // bounding boxes being sane, and a bad photo can produce geometry that scrambles a
    // panel the flat text would have parsed fine. Whichever text parses better wins.
    final deterministic = _bestParse(text, await _reconstructedText(imagePath));
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
