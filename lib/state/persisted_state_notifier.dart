/// Base for StateNotifiers that restore their value from the encrypted key-value store on
/// construction and persist it on change (TASK-35). It fixes a subtle save/load race the
/// hand-rolled notifiers had: the async restore runs after construction, so a `save()` that
/// lands *before* the restore finishes used to be clobbered when the late restore applied
/// the stale stored value. Here a local write latches, so an in-flight restore is discarded
/// once the user has changed anything.
///
/// Subclasses implement [load]/[store] with whatever KvStore accessors fit their value
/// (string+JSON, bool, double, …), and call [persist] to set + save.
///
/// TASK-188: corruption is LOUD, never silent. [restoreJsonGuarded] is the one decode
/// path for JSON blobs — on a corrupt value it logs an error, preserves the raw bytes
/// under `<key>.corrupt` for diagnosis, optionally posts a user-visible reset notice,
/// and returns null so the caller's defaults apply explicitly.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/kv_store.dart';
import '../logging/app_log.dart';

/// User-visible notices that persisted settings were reset after corruption
/// (TASK-188). The main shell shows these as a persistent banner; clinical
/// settings (therapy, alert thresholds) must be reviewed, not silently defaulted.
class CorruptStateNotices {
  static final ValueNotifier<List<String>> notices =
      ValueNotifier(const <String>[]);

  static void add(String message) => notices.value = [...notices.value, message];

  static void dismiss(String message) =>
      notices.value = [for (final m in notices.value) if (m != message) m];

  @visibleForTesting
  static void clear() => notices.value = const <String>[];
}

/// Decode the JSON blob stored at [key], or null when nothing is stored.
/// On a corrupt/mis-shaped value: log loudly, quarantine the raw string at
/// `<key>.corrupt` (the original key is left to be overwritten by the next save),
/// post [resetNotice] when given, and return null so defaults apply explicitly.
Future<T?> restoreJsonGuarded<T>({
  required String key,
  required T Function(Map<String, dynamic>) fromJson,
  String? resetNotice,
}) async {
  final raw = await KvStore.getString(key);
  if (raw == null) return null;
  try {
    return fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (e) {
    await quarantineCorruptValue(key, raw, e, resetNotice: resetNotice);
    return null;
  }
}

/// Shared corruption handling for restore paths that decode by hand (lists,
/// custom encodings): loud log + raw preserved at `<key>.corrupt` + optional
/// user-visible notice.
Future<void> quarantineCorruptValue(
  String key,
  String raw,
  Object error, {
  String? resetNotice,
}) async {
  appLog.error(
      'persistence',
      'corrupt persisted state "$key" — using defaults; raw value preserved at '
          '"$key.corrupt"',
      error: error);
  try {
    await KvStore.setString('$key.corrupt', raw);
  } catch (e) {
    appLog.error('persistence', 'quarantine write failed for "$key"', error: e);
  }
  if (resetNotice != null) CorruptStateNotices.add(resetNotice);
}

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
    } catch (e) {
      // TASK-188: never silent — a failed restore means running on defaults.
      appLog.error('persistence', '$runtimeType restore failed — keeping defaults',
          error: e);
      return;
    }
    // Re-check AFTER the await: a persist() may have landed while we were loading, in which
    // case the user's value wins and the stored (stale) one must not overwrite it.
    if (loaded == null || _hasLocalWrite) return;
    state = loaded;
  }

  /// Set the value and persist it. Latches a local write so a still-in-flight restore can
  /// never clobber it. Returns true once the write actually lands; on failure (TASK-198)
  /// it logs the error, reverts [state] to the last successfully-persisted value — so the
  /// rest of the app immediately stops using a value that isn't actually saved and would
  /// otherwise silently revert out from under the user on the next restart — and returns
  /// false so the caller can surface the failure instead of assuming it succeeded.
  Future<bool> persist(T value) async {
    final previous = state;
    // TASK-259: snapshot the latch, not just the value. If this attempt fails and it
    // was ALSO the first local write (hadLocalWrite false), _hasLocalWrite must revert
    // to false too -- otherwise it stays latched from a write that never actually
    // landed, and a concurrent in-flight _restore() discards the real persisted disk
    // value once its load() completes, silently running a dosing-relevant setting on
    // defaults. A prior GENUINE successful write (hadLocalWrite true) must still block
    // a stale restore, so this only reverts when there was nothing to protect.
    final hadLocalWrite = _hasLocalWrite;
    _hasLocalWrite = true;
    state = value;
    try {
      await store(value);
      return true;
    } catch (e) {
      appLog.error('persistence',
          '$runtimeType persist failed — reverting to the last saved value',
          error: e);
      state = previous;
      _hasLocalWrite = hadLocalWrite;
      return false;
    }
  }
}
