import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/state/persisted_state_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-35 AC#1: the restore-then-save race. A save that lands before the async restore
/// finishes must win — the stale stored value must never clobber the user's write.
class _IntNotifier extends PersistedStateNotifier<int> {
  _IntNotifier() : super(0);
  static const _key = 'test_int';
  @override
  Future<int?> load() async {
    final raw = await KvStore.getString(_key);
    return raw == null ? null : int.tryParse(raw);
  }

  @override
  Future<void> store(int v) => KvStore.setString(_key, '$v');
}

void main() {
  setUp(KvStore.useMemory);

  test('a save before restore completes is NOT clobbered by the stale stored value', () async {
    await KvStore.setString('test_int', '99'); // the previously-stored value

    final n = _IntNotifier(); // restore starts asynchronously
    // The user changes it immediately — before the in-flight restore's load() resolves.
    await n.persist(42);
    await n.restored; // let the restore finish

    expect(n.state, 42); // the write won; the stale 99 did not overwrite it
    expect(await KvStore.getString('test_int'), '42');
  });

  test('with no local write, restore applies the stored value', () async {
    await KvStore.setString('test_int', '77');
    final n = _IntNotifier();
    await n.restored;
    expect(n.state, 77);
  });

  test('no stored value keeps the default', () async {
    final n = _IntNotifier();
    await n.restored;
    expect(n.state, 0);
  });

  test('a corrupt stored value is ignored (keeps the default)', () async {
    await KvStore.setString('test_int', 'not-an-int');
    final n = _IntNotifier();
    await n.restored;
    expect(n.state, 0);
  });
}
