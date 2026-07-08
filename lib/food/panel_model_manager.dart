/// Manages the optional on-device nutrition-panel LLM model file (download / status /
/// delete) via flutter_gemma. The model (~0.5 GB Gemma 3 1B int4 `.task`) is downloaded on
/// demand from a user-provided URL — Gemma is licence-gated, so we can't bundle or hardcode
/// a working link — and stored in app files. The deterministic parser works without it.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PanelModelManager {
  /// [httpClient] is injectable for tests (TASK-246 AC#4: simulating a cross-host
  /// redirect needs control over the response chain); defaults to a real client.
  PanelModelManager({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Hosts trusted to receive the access token (TASK-16 AC#2) — the licence-gated
  /// hosts this feature's UI actually names (Hugging Face / Kaggle). The token is
  /// withheld from any other host rather than the download being refused outright,
  /// since a token-free download from an untrusted host is still safe to attempt.
  static const Set<String> tokenAllowedHosts = {
    'huggingface.co',
    'www.huggingface.co',
    'kaggle.com',
    'www.kaggle.com',
  };

  static const int _maxRedirects = 5;

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
  ///
  /// TASK-246: flutter_gemma's `fromNetwork(url, token: ...)` follows redirects via its
  /// own downloader, which does not guarantee the `Authorization` header is stripped on
  /// a cross-host redirect (gated Hugging Face URLs routinely 302 to a CDN host like
  /// `cdn-lfs.huggingface.co`, not itself allowlisted). Whenever a token would actually
  /// be sent, the download is instead fetched via [_downloadWithSafeRedirects] -- a
  /// client under our control that re-checks [tokenForHost] at every hop, not just the
  /// first -- and handed to flutter_gemma as a local file. A token-free download (the
  /// common case: no token, or a host outside the allowlist) has nothing to leak, so it
  /// keeps using flutter_gemma's own network path unchanged.
  Future<void> download({
    required String url,
    String? token,
    void Function(int percent)? onProgress,
  }) async {
    final uri = validateHttps(url);
    final effectiveToken = tokenForHost(uri, token);

    InferenceInstallationBuilder builder;
    if (effectiveToken != null) {
      final localPath = await _downloadWithSafeRedirects(
        uri: uri,
        token: effectiveToken,
        onProgress: onProgress,
      );
      builder = FlutterGemma.installModel(modelType: ModelType.gemmaIt)
          .fromFile(localPath);
    } else {
      builder = FlutterGemma.installModel(modelType: ModelType.gemmaIt)
          .fromNetwork(url);
      if (onProgress != null) {
        builder = builder.withProgress(onProgress);
      }
    }
    await builder.install();
  }

  /// Manually follows up to [_maxRedirects] redirects from [uri], re-evaluating
  /// [tokenForHost] against the CURRENT host at every hop (TASK-246 AC#1) -- [token] is
  /// attached to a request only while the host it's about to be sent to is still
  /// allowlisted, and is silently dropped the moment a redirect points anywhere else.
  /// Split out from the file-streaming step below so the header-stripping logic itself
  /// is directly testable with an injected [http.Client] (AC#4), no file I/O needed.
  /// Not private (unlike the rest of this class's internals) so the test file --
  /// necessarily a separate library -- can call it directly instead of exercising it
  /// only indirectly through [download]'s file-writing side effects.
  @visibleForTesting
  Future<http.StreamedResponse> resolveWithSafeRedirects(
      Uri uri, String token) async {
    var current = uri;
    var redirects = 0;
    while (true) {
      final request = http.Request('GET', current)..followRedirects = false;
      final sendToken = tokenForHost(current, token);
      if (sendToken != null) {
        request.headers['Authorization'] = 'Bearer $sendToken';
      }
      final response = await _httpClient.send(request);
      final isRedirect = response.statusCode >= 300 && response.statusCode < 400;
      final location = response.headers['location'];
      if (!isRedirect || location == null) return response;
      if (++redirects > _maxRedirects) {
        throw StateError('Model download rejected: too many redirects');
      }
      current = current.resolve(location);
    }
  }

  /// Streams [uri] to a local file via [resolveWithSafeRedirects]. Returns the
  /// downloaded file's path, ready for flutter_gemma's `fromFile()`.
  Future<String> _downloadWithSafeRedirects({
    required Uri uri,
    required String token,
    void Function(int percent)? onProgress,
  }) async {
    final response = await resolveWithSafeRedirects(uri, token);
    if (response.statusCode != 200) {
      throw StateError('Model download failed: HTTP ${response.statusCode}');
    }

    final dir = await getTemporaryDirectory();
    final fileName = fileNameFor(uri.toString());
    final file = File(p.join(dir.path, fileName));
    final sink = file.openWrite();
    final total = response.contentLength;
    var received = 0;
    await response.stream.listen((chunk) {
      sink.add(chunk);
      received += chunk.length;
      if (onProgress != null && total != null && total > 0) {
        onProgress((received * 100 / total).floor().clamp(0, 100));
      }
    }).asFuture<void>();
    await sink.close();
    return file.path;
  }

  Future<void> delete(String url) async {
    try {
      await FlutterGemma.uninstallModel(fileNameFor(url));
    } catch (_) {}
  }
}
