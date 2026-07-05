/// Manages the optional on-device nutrition-panel LLM model file (download / status /
/// delete) via flutter_gemma. The model (~0.5 GB Gemma 3 1B int4 `.task`) is downloaded on
/// demand from a user-provided URL — Gemma is licence-gated, so we can't bundle or hardcode
/// a working link — and stored in app files. The deterministic parser works without it.
library;

import 'package:flutter_gemma/flutter_gemma.dart';

class PanelModelManager {
  const PanelModelManager();

  /// The filename flutter_gemma stores/keys the model under — the last URL path segment.
  static String fileNameFor(String url) {
    final segments = Uri.tryParse(url)?.pathSegments ?? const [];
    final last = segments.isEmpty ? '' : segments.last;
    return last.isEmpty ? 'panel-llm.task' : last;
  }

  Future<bool> isInstalled(String url) async {
    try {
      return await FlutterGemma.isModelInstalled(fileNameFor(url));
    } catch (_) {
      return false;
    }
  }

  /// Download the model from [url] (with an optional HF/Kaggle [token]) and set it active.
  /// [onProgress] receives 0–100.
  Future<void> download({
    required String url,
    String? token,
    void Function(int percent)? onProgress,
  }) async {
    var builder = FlutterGemma.installModel(modelType: ModelType.gemmaIt)
        .fromNetwork(url, token: token);
    if (onProgress != null) {
      builder = builder.withProgress(onProgress);
    }
    await builder.install();
  }

  Future<void> delete(String url) async {
    try {
      await FlutterGemma.uninstallModel(fileNameFor(url));
    } catch (_) {}
  }
}
