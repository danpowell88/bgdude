import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/food/panel_model_manager.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-204: a controllable double for PanelModelManager -- lets tests simulate a
/// "truncated model file" (installed==true per a bare file-existence check, exactly
/// what flutter_gemma's real isModelInstalled does) without touching the real
/// ~0.5 GB flutter_gemma download/native path.
class _FakeModelManager extends PanelModelManager {
  _FakeModelManager({Set<String>? installedUrls})
      : installedUrls = installedUrls ?? {};

  final Set<String> installedUrls;
  final List<String> deletedUrls = [];
  Exception? downloadError;

  @override
  Future<bool> isInstalled(String url) async => installedUrls.contains(url);

  @override
  Future<void> delete(String url) async {
    deletedUrls.add(url);
    installedUrls.remove(url);
  }

  @override
  Future<void> download({
    required String url,
    String? token,
    void Function(int percent)? onProgress,
  }) async {
    if (downloadError != null) throw downloadError!;
    installedUrls.add(url);
  }
}

void main() {
  setUp(KvStore.useMemory);

  group('PanelModelController restore (TASK-204 AC#1)', () {
    test(
        'an in-flight-download marker left from a crashed session deletes the '
        'partial file and does not mark installed', () async {
      const url = 'https://huggingface.co/model.task';
      // Simulate: a download of `url` was in progress when the app died. The
      // partial file happens to exist on disk (isInstalled would say true, per
      // flutter_gemma's bare file-existence check) -- but the marker says it was
      // never confirmed complete.
      await KvStore.setString('panel_llm_downloading_v1', url);
      final mgr = _FakeModelManager(installedUrls: {url});

      final container = ProviderContainer(overrides: [
        panelModelProvider.overrideWith(
            (ref) => PanelModelController(ref, manager: mgr)),
      ]);
      addTearDown(container.dispose);
      container.read(panelModelProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(mgr.deletedUrls, contains(url));
      expect(container.read(panelModelProvider).installed, isFalse);
    });

    test('no in-flight marker: a genuinely-installed model restores normally',
        () async {
      const url = 'https://huggingface.co/model.task';
      await KvStore.setString('panel_llm_url_v1', url);
      final mgr = _FakeModelManager(installedUrls: {url});

      final container = ProviderContainer(overrides: [
        panelModelProvider.overrideWith(
            (ref) => PanelModelController(ref, manager: mgr)),
      ]);
      addTearDown(container.dispose);
      container.read(panelModelProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(mgr.deletedUrls, isEmpty);
      expect(container.read(panelModelProvider).installed, isTrue);
    });
  });

  group('PanelModelController.download (TASK-204)', () {
    test('clears the in-flight marker on both success and failure', () async {
      const url = 'https://huggingface.co/model.task';
      final mgr = _FakeModelManager();
      final container = ProviderContainer(overrides: [
        panelModelProvider.overrideWith(
            (ref) => PanelModelController(ref, manager: mgr)),
      ]);
      addTearDown(container.dispose);

      await container.read(panelModelProvider.notifier).download(url);
      expect(await KvStore.getString('panel_llm_downloading_v1'), anyOf(isNull, ''));
      expect(container.read(panelModelProvider).installed, isTrue);

      mgr.downloadError = Exception('network died mid-download');
      await expectLater(
          container.read(panelModelProvider.notifier).download('$url.v2'),
          throwsException);
      expect(await KvStore.getString('panel_llm_downloading_v1'), anyOf(isNull, ''));
      // The partial file from the failed attempt was cleaned up, not left behind.
      expect(mgr.deletedUrls, contains('$url.v2'));
    });
  });

  group('PanelModelController.markLoadFailed (TASK-204 AC#2)', () {
    test('clears installed and deletes the file', () async {
      const url = 'https://huggingface.co/model.task';
      final mgr = _FakeModelManager(installedUrls: {url});
      await KvStore.setString('panel_llm_url_v1', url);

      final container = ProviderContainer(overrides: [
        panelModelProvider.overrideWith(
            (ref) => PanelModelController(ref, manager: mgr)),
      ]);
      addTearDown(container.dispose);
      container.read(panelModelProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(panelModelProvider).installed, isTrue);

      await container.read(panelModelProvider.notifier).markLoadFailed();

      expect(container.read(panelModelProvider).installed, isFalse);
      expect(mgr.deletedUrls, contains(url));
    });
  });
}
