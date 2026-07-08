import 'package:bgdude/food/panel_model_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PanelModelManager.fileNameFor', () {
    test('uses the last URL path segment as the model id', () {
      expect(
        PanelModelManager.fileNameFor(
            'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task'),
        'gemma3-1b-it-int4.task',
      );
    });

    test('ignores query strings', () {
      expect(
        PanelModelManager.fileNameFor(
            'https://example.com/models/panel.task?download=true'),
        'panel.task',
      );
    });

    test('falls back to a default when the URL has no filename', () {
      expect(PanelModelManager.fileNameFor('https://example.com/'),
          'panel-llm.task');
      expect(PanelModelManager.fileNameFor(''), 'panel-llm.task');
    });
  });

  group('PanelModelManager.validateHttps (TASK-16 AC#1)', () {
    test('accepts an HTTPS URL', () {
      expect(
          PanelModelManager.validateHttps('https://huggingface.co/x.task').scheme,
          'https');
    });

    test('rejects HTTP', () {
      expect(() => PanelModelManager.validateHttps('http://huggingface.co/x.task'),
          throwsArgumentError);
    });

    test('rejects an unparseable URL', () {
      expect(() => PanelModelManager.validateHttps('not a url'),
          throwsArgumentError);
    });

    test('the rejection message never echoes the URL (AC#4)', () {
      const secretUrl = 'http://evil.example/token-leak-check';
      try {
        PanelModelManager.validateHttps(secretUrl);
        fail('expected ArgumentError');
      } on ArgumentError catch (e) {
        expect(e.toString(), isNot(contains('evil.example')));
      }
    });
  });

  group('PanelModelManager.tokenForHost (TASK-16 AC#2)', () {
    test('sends the token to Hugging Face', () {
      final uri = Uri.parse('https://huggingface.co/x.task');
      expect(PanelModelManager.tokenForHost(uri, 'secret'), 'secret');
    });

    test('sends the token to Kaggle (bare and www)', () {
      expect(
          PanelModelManager.tokenForHost(
              Uri.parse('https://kaggle.com/x.task'), 'secret'),
          'secret');
      expect(
          PanelModelManager.tokenForHost(
              Uri.parse('https://www.kaggle.com/x.task'), 'secret'),
          'secret');
    });

    test('withholds the token from a non-allowlisted host', () {
      final uri = Uri.parse('https://evil.example/x.task');
      expect(PanelModelManager.tokenForHost(uri, 'secret'), isNull);
    });

    test('withholds a null token regardless of host', () {
      final uri = Uri.parse('https://huggingface.co/x.task');
      expect(PanelModelManager.tokenForHost(uri, null), isNull);
    });
  });

  group('PanelModelManager.resolveWithSafeRedirects (TASK-246)', () {
    test('withholds the token after a redirect to a non-allowlisted host',
        () async {
      final requests = <http.BaseRequest>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.host == 'huggingface.co') {
          return http.Response('', 302,
              headers: {'location': 'https://cdn-lfs.huggingface.co/x.task'});
        }
        return http.Response('model bytes', 200);
      });

      final manager = PanelModelManager(httpClient: client);
      final response = await manager.resolveWithSafeRedirects(
          Uri.parse('https://huggingface.co/x.task'), 'secret-token');

      expect(response.statusCode, 200);
      expect(requests, hasLength(2));
      expect(requests[0].url.host, 'huggingface.co');
      expect(requests[0].headers['Authorization'], 'Bearer secret-token',
          reason: 'the first, allowlisted hop should carry the token');
      expect(requests[1].url.host, 'cdn-lfs.huggingface.co');
      expect(requests[1].headers.containsKey('Authorization'), isFalse,
          reason: 'a redirect off the allowlist must not carry the token '
              'forward -- this is the exact leak AC#1 guards against');
    });

    test('keeps the token attached across a redirect that stays within the '
        'allowlist', () async {
      final requests = <http.BaseRequest>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.host == 'huggingface.co') {
          return http.Response('', 302,
              headers: {'location': 'https://www.huggingface.co/x.task'});
        }
        return http.Response('model bytes', 200);
      });

      final manager = PanelModelManager(httpClient: client);
      await manager.resolveWithSafeRedirects(
          Uri.parse('https://huggingface.co/x.task'), 'secret-token');

      expect(requests[1].url.host, 'www.huggingface.co');
      expect(requests[1].headers['Authorization'], 'Bearer secret-token',
          reason: 'both hops are allowlisted, so the token should still '
              'reach the final host');
    });

    test('gives up after too many redirects rather than looping forever',
        () async {
      var hop = 0;
      final client = MockClient((request) async {
        hop++;
        return http.Response('', 302,
            headers: {'location': 'https://huggingface.co/x$hop.task'});
      });

      final manager = PanelModelManager(httpClient: client);
      await expectLater(
        manager.resolveWithSafeRedirects(
            Uri.parse('https://huggingface.co/x0.task'), 'secret-token'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
