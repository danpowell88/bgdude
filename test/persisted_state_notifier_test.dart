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

/// TASK-198 AC#4: a store() that always fails, to exercise persist()'s failure path.
class _ThrowingIntNotifier extends PersistedStateNotifier<int> {
  _ThrowingIntNotifier() : super(0);
  static const _key = 'test_int_throwing';
  bool shouldThrow = true;

  @override
  Future<int?> load() async {
    final raw = await KvStore.getString(_key);
    return raw == null ? null : int.tryParse(raw);
  }

  @override
  Future<void> store(int v) async {
    if (shouldThrow) throw StateError('simulated write failure');
    await KvStore.setString(_key, '$v');
  }
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

  group('persist() failure handling (TASK-198)', () {
    test('a throwing store() causes persist() to return false', () async {
      final n = _ThrowingIntNotifier();
      await n.restored;
      final ok = await n.persist(42);
      expect(ok, isFalse);
    });

    test('state is reverted to the last saved value, not treated as persisted',
        () async {
      final n = _ThrowingIntNotifier();
      await n.restored;
      expect(n.state, 0); // last known-good value

      await n.persist(42);
      // The failed write must NOT leave the in-memory state looking saved —
      // otherwise the rest of the app keeps using a value that will silently
      // revert on the next restart (the exact bug TASK-198 fixes).
      expect(n.state, 0);
      expect(await KvStore.getString(_ThrowingIntNotifier._key), isNull);
    });

    test('a later successful persist still works after an earlier failure',
        () async {
      final n = _ThrowingIntNotifier();
      await n.restored;
      await n.persist(42);
      expect(n.state, 0);

      n.shouldThrow = false;
      final ok = await n.persist(7);
      expect(ok, isTrue);
      expect(n.state, 7);
      expect(await KvStore.getString(_ThrowingIntNotifier._key), '7');
    });
  });
}
