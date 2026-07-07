/// Manages the optional on-device nutrition-panel LLM model file (download / status /
/// delete) via flutter_gemma. The model (~0.5 GB Gemma 3 1B int4 `.task`) is downloaded on
/// demand from a user-provided URL — Gemma is licence-gated, so we can't bundle or hardcode
/// a working link — and stored in app files. The deterministic parser works without it.
library;

import 'package:flutter_gemma/flutter_gemma.dart';

class PanelModelManager {
  const PanelModelManager();

  /// Hosts trusted to receive the access token (TASK-16 AC#2) — the licence-gated
  /// hosts this feature's UI actually names (Hugging Face / Kaggle). The token is
  /// withheld from any other host rather than the download being refused outright,
  /// since a token-free download from an untrusted host is still safe to attempt.
  static const Set<String> tokenAllowedHosts = {
    'huggingface.co',
    'kaggle.com',
    'www.kaggle.com',
  };

  /// Rejects non-HTTPS model URLs (TASK-16 AC#1). The message is deliberately
  /// generic — never embeds the URL/token (AC#4) — since exception messages can
  /// end up in crash-reporting breadcrumbs.
  static Uri validateHttps(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      throw ArgumentError('Model download rejected: URL must use HTTPS');
    }
    return uri;
  }

  /// The token to actually send with the request, withheld (null) unless [uri]'s
  /// host is in [tokenAllowedHosts] (TASK-16 AC#2).
  static String? tokenForHost(Uri uri, String? token) =>
      token != null && tokenAllowedHosts.contains(uri.host) ? token : null;

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
    final uri = validateHttps(url);
    final effectiveToken = tokenForHost(uri, token);
    var builder = FlutterGemma.installModel(modelType: ModelType.gemmaIt)
        .fromNetwork(url, token: effectiveToken);
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
