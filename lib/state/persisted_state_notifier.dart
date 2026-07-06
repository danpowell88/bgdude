/// Base for StateNotifiers that restore their value from the encrypted key-value store on
/// construction and persist it on change (TASK-35). It fixes a subtle save/load race the
/// hand-rolled notifiers had: the async restore runs after construction, so a `save()` that
/// lands *before* the restore finishes used to be clobbered when the late restore applied
/// the stale stored value. Here a local write latches, so an in-flight restore is discarded
/// once the user has changed anything.
///
/// Subclasses implement [load]/[store] with whatever KvStore accessors fit their value
/// (string+JSON, bool, double, …), and call [persist] to set + save.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class PersistedStateNotifier<T> extends StateNotifier<T> {
  PersistedStateNotifier(super.initial) {
    restored = _restore();
  }

  /// Load the persisted value, or null when nothing is stored.
  Future<T?> load();

  /// Persist [value].
  Future<void> store(T value);

  /// Completes when the initial restore has finished — useful in tests.
  late final Future<void> restored;

  bool _hasLocalWrite = false;

  Future<void> _restore() async {
    final T? loaded;
    try {
      loaded = await load();
    } catch (_) {
      return; // corrupt/legacy payload — keep the default
    }
    // Re-check AFTER the await: a persist() may have landed while we were loading, in which
    // case the user's value wins and the stored (stale) one must not overwrite it.
    if (loaded == null || _hasLocalWrite) return;
    state = loaded;
  }

  /// Set the value and persist it. Latches a local write so a still-in-flight restore can
  /// never clobber it.
  Future<void> persist(T value) async {
    _hasLocalWrite = true;
    state = value;
    await store(value);
  }
}
