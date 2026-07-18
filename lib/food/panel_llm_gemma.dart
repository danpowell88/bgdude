/// On-device Gemma implementation of [PanelLlmExtractor] (via flutter_gemma / LiteRT).
///
/// Constructed only when a model is installed (see `panelLlmProvider`), so [available] is
/// true. [extract] loads the active model on demand, runs the JSON-extraction prompt at a
/// low temperature, then frees the model again so ~1.5 GB isn't held resident between
/// scans. Any failure (no model, OOM, timeout, malformed output) returns null, so the scan
/// service falls back to the deterministic parse — the LLM is never on the critical path.
library;

import 'package:flutter_gemma/flutter_gemma.dart';

import 'meal_estimate.dart';
import 'meal_estimate_service.dart';
import 'nutrition_panel.dart';
import 'panel_llm.dart';

class GemmaPanelExtractor implements PanelLlmExtractor {
  const GemmaPanelExtractor({this.onModelLoadFailed});

  /// Called when the model itself fails to LOAD (as opposed to a later inference
  /// failure, timeout, or OOM on an otherwise-good model) — TASK-204: this
  /// specifically signals the installed file is likely corrupt/truncated, so the
  /// caller (panelModelProvider, which has the state this class doesn't) can
  /// clear the installed flag instead of silently re-attempting a broken file on
  /// every single scan.
  final void Function(Object error)? onModelLoadFailed;

  @override
  bool get available => true;

  @override
  Future<PanelNutrition?> extract(String ocrText) async {
    InferenceModel? model;
    InferenceModelSession? session;
    try {
      try {
        model = await FlutterGemma.getActiveModel(
          maxTokens: 2048,
          preferredBackend: PreferredBackend.cpu,
        );
      } catch (e) {
        onModelLoadFailed?.call(e);
        rethrow;
      }
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

/// Free-text meal estimation on the same on-device model (issue #79).
///
/// Mirrors [GemmaPanelExtractor]'s session handling — greedy decoding, a hard timeout,
/// and close-after-use — because the failure that matters is the same one: a session
/// left open holds the model in memory and the next scan OOMs.
class GemmaMealEstimator implements MealEstimator {
  const GemmaMealEstimator({this.onModelLoadFailed});

  /// See [GemmaPanelExtractor.onModelLoadFailed] — signals a corrupt/truncated file
  /// rather than an inference failure, so the caller can clear the installed flag.
  final void Function(Object error)? onModelLoadFailed;

  @override
  bool get available => true;

  @override
  Future<MealEstimate?> estimate(String description) async {
    InferenceModel? model;
    InferenceModelSession? session;
    try {
      try {
        model = await FlutterGemma.getActiveModel(
          maxTokens: 2048,
          preferredBackend: PreferredBackend.cpu,
        );
      } catch (e) {
        onModelLoadFailed?.call(e);
        rethrow;
      }
      // Greedy: we want a consistent estimate, not a creative one.
      session = await model.createSession(temperature: 0.0, topK: 1);
      await session.addQueryChunk(
          Message.text(text: buildMealEstimatePrompt(description), isUser: true));
      final response =
          await session.getResponse().timeout(const Duration(seconds: 45));
      return parseMealEstimateJson(response);
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
