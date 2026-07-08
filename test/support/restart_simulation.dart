/// A reusable harness for simulating a process crash-and-restart over the
/// same persistence. `KvStore` (lib/data/kv_store.dart) holds its in-memory fallback
/// in a static map that survives across `ProviderContainer`s as long as
/// `KvStore.useMemory()` isn't called again — call it exactly ONCE per test, then
/// build a container, do things, dispose it (no graceful shutdown — a real crash
/// doesn't get one either), and build a fresh container to assert what actually
/// survived.
library;

import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resets the shared in-memory KvStore backing ONCE, then returns a builder that
/// creates fresh [ProviderContainer]s sharing the SAME [repo] (standing in for "the
/// same on-disk database") and the SAME now-cleared KvStore backing (standing in for
/// "the same on-disk prefs/settings file"). Call [buildContainer] once per simulated
/// process lifetime; each call models a fresh app launch over persisted state.
///
/// TASK-256: [repo] is typed as the plain [HistoryRepository] interface (not
/// [InMemoryHistoryRepository]) so a scenario can pass a
/// [FaultInjectingHistoryRepository] wrapping an [InMemoryHistoryRepository] delegate
/// -- a mid-write crash is simulated by making one call throw with `throwOnce`, then
/// disposing the container (no graceful shutdown, matching a real crash); the SAME
/// [repo] instance is reused for the "restarted" container, exactly as the underlying
/// on-disk database itself would still be the same file after a real crash. throwOnce
/// self-clears after firing, so the restarted container's calls behave normally
/// again without any extra reset step.
class RestartSimulation {
  RestartSimulation({HistoryRepository? repo})
      : repo = repo ?? InMemoryHistoryRepository() {
    KvStore.useMemory();
  }

  final HistoryRepository repo;

  /// Builds a fresh container — a new "process" — over the same [repo]/KvStore.
  /// [extraOverrides] lets a test add scenario-specific overrides on top of the
  /// baseline ones every simulated launch needs.
  ProviderContainer buildContainer({List<Override> extraOverrides = const []}) {
    return ProviderContainer(overrides: [
      historyRepositoryProvider.overrideWithValue(repo),
      notificationServiceProvider.overrideWithValue(NotificationService()),
      devModeProvider.overrideWith((ref) => false),
      therapySettingsProvider.overrideWith((ref) => TherapyNotifier()),
      ...extraOverrides,
    ]);
  }
}
