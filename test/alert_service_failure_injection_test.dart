/// TASK-211: pins the failure-handling behaviour of `AlertService.onSnapshot` (see
/// `lib/state/providers.dart`) that today only exists as an unpinned convention — a
/// refactor (e.g. another TASK-116-style extraction) could silently invert the
/// show/markFired order, or let one category's exception abort the rest of the cycle,
/// without any test failing. Nothing here changes behaviour; every assertion documents
/// what already happens.
library;

import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/faults.dart';
import 'support/samples.dart';

void main() {
  setUp(KvStore.useMemory);

  final now = DateTime(2026, 7, 8, 12);

  DayData dayData() => DayData(
        start: now.subtract(const Duration(hours: 24)),
        end: now,
        cgm: const [],
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: testTherapySettings(),
        context: null,
        isSimulated: false,
      );

  // Current 100, forecast dips to 50 in 20 min -- below the default urgentLowMgdl (55),
  // so AlertMonitor decides urgentLow with AlertUrgency.critical (mirrors the identical
  // setup in alert_orchestrator_test.dart's "a predicted urgent low outranks the plain
  // low" case, which is already pinned at the pure-orchestrator level).
  PredictionState urgentLowState() => PredictionState(
        now: now,
        currentMgdl: 100,
        recentRocMgdlPerMin: 0,
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: testTherapySettings(),
      );

  ({
    ProviderContainer container,
    ThrowingNotificationService notifier,
    FaultInjectingHistoryRepository repo,
  }) build({
    PumpSnapshot? snapshot,
    List<HorizonForecast> forecasts = const [],
    bool includeGlucoseState = true,
  }) {
    final notifier = ThrowingNotificationService();
    final repo = FaultInjectingHistoryRepository();
    final container = ProviderContainer(overrides: [
      notificationServiceProvider.overrideWithValue(notifier),
      historyRepositoryProvider.overrideWithValue(repo),
      pumpSnapshotProvider.overrideWith(
          (ref) => Stream.value(snapshot ?? PumpSnapshot(time: now, cgmMgdl: 100))),
      dayDataProvider.overrideWithValue(dayData()),
      livePredictionStateProvider
          .overrideWithValue(includeGlucoseState ? urgentLowState() : null),
      calibratedForecastsProvider.overrideWithValue(forecasts),
      // rescueCarbAdviceProvider (unused by these tests) otherwise pulls in
      // recentAnnotationsProvider -> the real dayHistoryControllerProvider, which
      // outlives a single onSnapshot() call and trips over container.dispose().
      rescueCarbAdviceProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    return (container: container, notifier: notifier, repo: repo);
  }

  final urgentForecast = [
    HorizonForecast(horizonMinutes: 20, mgdl: 50, lowerMgdl: 40, upperMgdl: 60)
  ];

  group('AC1: a failed urgent-low send is retried, not silently dropped', () {
    test('onSnapshot never throws even though every notification send fails',
        () async {
      final env = build(forecasts: urgentForecast);
      env.notifier.shouldThrow = true;

      await expectLater(
          env.container.read(alertServiceProvider).onSnapshot(), completes);
    });

    test('a second cycle retries the urgent low (fired twice, not deduped away)',
        () async {
      final env = build(forecasts: urgentForecast);
      env.notifier.shouldThrow = true;

      await env.container.read(alertServiceProvider).onSnapshot();
      await env.container.read(alertServiceProvider).onSnapshot();

      // markFired only happens AFTER a successful show() (AlertUrgency.critical path),
      // so a failing send must not advance the cooldown -- the second cycle attempts
      // the exact same urgentLow send again instead of treating it as already-fired.
      final urgentLowAttempts =
          env.notifier.shown.where((c) => c == NotificationCategory.urgentLow).length;
      expect(urgentLowAttempts, 2);
    });

    test('once a send succeeds, an immediately-following cycle does not re-fire',
        () async {
      final env = build(forecasts: urgentForecast);
      env.notifier.shouldThrow = false; // sends succeed this time

      await env.container.read(alertServiceProvider).onSnapshot();
      await env.container.read(alertServiceProvider).onSnapshot();

      // The repeat cooldown (>=30 min floor) means the second cycle, run moments
      // later, must not re-fire a category that just succeeded.
      final urgentLowAttempts =
          env.notifier.shown.where((c) => c == NotificationCategory.urgentLow).length;
      expect(urgentLowAttempts, 1);
    });
  });

  group('AC2: one category throwing does not stop later categories', () {
    test('a pump alarm (throws) and a low reservoir (also attempted) both evaluate',
        () async {
      final snap = PumpSnapshot(
        time: now,
        activeAlarms: const ['LOW_INSULIN_ALARM'],
        reservoirUnits: 5, // below the 15u reservoirLowUnits line
      );
      final env = build(
          snapshot: snap, includeGlucoseState: false /* isolate pump-status alerts */);
      env.notifier.shouldThrow = true; // every show() throws

      // onSnapshot reads pumpSnapshotProvider synchronously (.valueOrNull); wait for
      // the overridden Stream.value to actually emit before that read happens.
      await env.container.read(pumpSnapshotProvider.future);
      await env.container.read(alertServiceProvider).onSnapshot();

      // Both decisions were attempted -- the reservoir category is only reached if the
      // pump-alarm category's earlier throw did not break the for-loop.
      expect(env.notifier.shown,
          containsAll(<NotificationCategory>[
            NotificationCategory.pumpAlarm,
            NotificationCategory.reservoirLow,
          ]));
    });
  });

  group('AC3: a faulty repository does not abort the alert cycle', () {
    test('savePrediction throwing on every call still lets onSnapshot complete',
        () async {
      final env = build(forecasts: urgentForecast);
      env.notifier.shouldThrow = false;
      env.repo.failOn('savePrediction');

      // Must not throw: the prediction-log loop catches per-entry and continues.
      await expectLater(
          env.container.read(alertServiceProvider).onSnapshot(), completes);

      // The urgent-low alert itself (unrelated to the repository) still fired.
      expect(env.notifier.shown, contains(NotificationCategory.urgentLow));
    });
  });
}
