/// On-device Gemma implementation of [PanelLlmExtractor] (via flutter_gemma / LiteRT).
///
/// Constructed only when a model is installed (see `panelLlmProvider`), so [available] is
/// true. [extract] loads the active model on demand, runs the JSON-extraction prompt at a
/// low temperature, then frees the model again so ~1.5 GB isn't held resident between
/// scans. Any failure (no model, OOM, timeout, malformed output) returns null, so the scan
/// service falls back to the deterministic parse — the LLM is never on the critical path.
library;

import 'package:flutter_gemma/flutter_gemma.dart';

import 'nutrition_panel.dart';
import 'panel_llm.dart';

class GemmaPanelExtractor implements PanelLlmExtractor {
  const GemmaPanelExtractor();

  @override
  bool get available => true;

  @override
  Future<PanelNutrition?> extract(String ocrText) async {
    InferenceModel? model;
    InferenceModelSession? session;
    try {
      model = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        preferredBackend: PreferredBackend.cpu,
      );
      // Low temperature: we want the label's numbers, not prose.
      session = await model.createSession(temperature: 0.0, topK: 1);
      await session
          .addQueryChunk(Message.text(text: buildPanelPrompt(ocrText), isUser: true));
      final response =
          await session.getResponse().timeout(const Duration(seconds: 45));
      return parsePanelLlmJson(response, rawText: ocrText);
    } catch (_) {
      return null;
    } finally {
      try {
        await session?.close();
      } catch (_) {}
      try {
        await model?.close();
      } catch (_) {}
    }
  }
}
