import 'dart:async';

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

/// TASK-259: a `load()` that blocks on an externally-controlled gate, so a test can
/// force a `persist()` failure to land WHILE the initial restore is still in flight.
class _SlowLoadIntNotifier extends PersistedStateNotifier<int> {
  _SlowLoadIntNotifier(this._loadGate) : super(0);
  static const _key = 'test_int_slow_load';
  final Completer<void> _loadGate;
  bool shouldThrow = true;

  @override
  Future<int?> load() async {
    await _loadGate.future;
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

    test('a persist failure racing an in-flight restore does not suppress the '
        'real disk value once load() completes (TASK-259)', () async {
      await KvStore.setString(_SlowLoadIntNotifier._key, '55'); // the real disk value
      final loadGate = Completer<void>();
      final n = _SlowLoadIntNotifier(loadGate); // _restore() is now blocked on loadGate

      // A local write attempt fails WHILE the restore's load() is still in flight.
      final ok = await n.persist(42);
      expect(ok, isFalse);
      expect(n.state, 0); // reverted, not left looking saved

      // Now let the in-flight load() resolve with the real disk value.
      loadGate.complete();
      await n.restored;

      // The failed persist must not have latched _hasLocalWrite -- the real disk
      // value wins, not the default (the exact bug this ticket fixes: without the
      // revert, this would still be 0, silently running on defaults).
      expect(n.state, 55);
    });

    test('a GENUINE prior local write still blocks a stale restore even after a '
        'later persist failure (the latch must not over-revert)', () async {
      await KvStore.setString(_SlowLoadIntNotifier._key, '55'); // stale disk value
      final loadGate = Completer<void>();
      final n = _SlowLoadIntNotifier(loadGate);

      // First write succeeds -- a genuine local write has now happened.
      n.shouldThrow = false;
      expect(await n.persist(1), isTrue);

      // A second write then fails, still while the restore is in flight.
      n.shouldThrow = true;
      expect(await n.persist(2), isFalse);
      expect(n.state, 1); // reverted to the last successfully-saved value

      // The restore must NOT clobber it with the stale disk value -- there WAS a
      // genuine local write, so _hasLocalWrite must still be latched.
      loadGate.complete();
      await n.restored;
      expect(n.state, 1);
    });
  });
}
