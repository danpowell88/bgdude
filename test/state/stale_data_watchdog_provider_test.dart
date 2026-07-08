/// TASK-230: StaleDataWatchdogService must own only the connected-but-silent case --
/// ConnectionAlertService already owns a genuine BLE disconnect (connectionLost). Before
/// this gate, a real disconnect fired BOTH connectionLost (10 min) and a
/// factually-wrong dataStale ("even though the connection looks healthy", 15 min).
library;

import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/faults.dart';

void main() {
  setUp(KvStore.useMemory);

  ({ProviderContainer container, ThrowingNotificationService notifier})
      build(PumpConnectionStage stage) {
    final notifier = ThrowingNotificationService()..shouldThrow = false;
    final container = ProviderContainer(overrides: [
      notificationServiceProvider.overrideWithValue(notifier),
      pumpConnectionProvider
          .overrideWith((ref) => Stream.value(PumpConnection(stage: stage))),
    ]);
    addTearDown(container.dispose);
    return (container: container, notifier: notifier);
  }

  test('disconnected + stale age fires no dataStale', () async {
    final env = build(PumpConnectionStage.disconnected);
    await env.container.read(pumpConnectionProvider.future);
    final service = env.container.read(staleDataWatchdogProvider);

    service.monitor.onSnapshot(
        DateTime.now().subtract(const Duration(minutes: 20))); // now-ok: simulate a stale-aged last reading
    await service.checkNow();

    expect(env.notifier.shown, isNot(contains(NotificationCategory.dataStale)));
  });

  test('connected + stale age still fires dataStale', () async {
    final env = build(PumpConnectionStage.connected);
    await env.container.read(pumpConnectionProvider.future);
    final service = env.container.read(staleDataWatchdogProvider);

    service.monitor.onSnapshot(
        DateTime.now().subtract(const Duration(minutes: 20))); // now-ok: simulate a stale-aged last reading
    await service.checkNow();

    expect(env.notifier.shown, contains(NotificationCategory.dataStale));
  });

  test('a disconnect resets the monitor so a later reconnect does not '
      'immediately re-flag on the accrued age', () async {
    final env = build(PumpConnectionStage.disconnected);
    await env.container.read(pumpConnectionProvider.future);
    final service = env.container.read(staleDataWatchdogProvider);

    service.monitor.onSnapshot(
        DateTime.now().subtract(const Duration(minutes: 20))); // now-ok: simulate a stale-aged last reading
    await service.checkNow(); // bails: not connected -- and resets the monitor
    expect(env.notifier.shown, isEmpty);
    expect(service.monitor.age(DateTime.now()), isNull); // now-ok: prove reset happened
  });

  test('recovery/reset behaviour is unchanged for the connected case '
      '(one alert per stall, recovers, a new stall re-alerts)', () async {
    final env = build(PumpConnectionStage.connected);
    await env.container.read(pumpConnectionProvider.future);
    final service = env.container.read(staleDataWatchdogProvider);

    service.monitor.onSnapshot(
        DateTime.now().subtract(const Duration(minutes: 20))); // now-ok: simulate a stale-aged last reading
    await service.checkNow();
    expect(
        env.notifier.shown
            .where((c) => c == NotificationCategory.dataStale)
            .length,
        1);

    // Persisting stall: no re-fire (matches the pure monitor's contract).
    await service.checkNow();
    expect(
        env.notifier.shown
            .where((c) => c == NotificationCategory.dataStale)
            .length,
        1);

    // A fresh snapshot recovers the stall.
    service.onSnapshot();
    await service.checkNow();
    expect(
        env.notifier.shown
            .where((c) => c == NotificationCategory.dataStale)
            .length,
        1);

    // A NEW stall (readings stop again) re-alerts.
    service.monitor.onSnapshot(
        DateTime.now().subtract(const Duration(minutes: 20))); // now-ok: simulate a stale-aged last reading
    await service.checkNow();
    expect(
        env.notifier.shown
            .where((c) => c == NotificationCategory.dataStale)
            .length,
        2);
  });
}
