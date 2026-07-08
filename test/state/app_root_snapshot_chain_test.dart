/// TASK-212: the app-root per-snapshot chain in `lib/app.dart` fires three independent,
/// contained side effects on every pump snapshot -- widget push, ingest+alerts (via the
/// TASK-125 `ingestThenEvaluateAlerts` seam), and a Nightscout upload. This exercises each
/// with a REAL component (not a fake closure) so a failure in one is proven not to drop the
/// reading, block alert evaluation, or escape as an unhandled error.
library;

import 'dart:async';

import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/units.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/integrations/nightscout.dart';
import 'package:bgdude/logging/app_log.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/state/day_history_controller.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/state/snapshot_chain.dart';
import 'package:bgdude/widget/home_widget_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/faults.dart';
import '../support/samples.dart';

class _ThrowingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw Exception('network down');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(KvStore.useMemory);

  final now = DateTime(2026, 7, 8, 12);

  PumpSnapshot urgentLowSnapshot() => PumpSnapshot(
        time: now,
        cgmMgdl: 100,
        cgmTime: now,
        cgmTrend: GlucoseTrend.flat,
      );

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

  // Current 100, forecast dips to 50 in 20 min -- below the default urgentLowMgdl (55).
  PredictionState urgentLowState() => PredictionState(
        now: now,
        currentMgdl: 100,
        recentRocMgdlPerMin: 0,
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: testTherapySettings(),
      );

  final urgentForecast = [
    HorizonForecast(horizonMinutes: 20, mgdl: 50, lowerMgdl: 40, upperMgdl: 60)
  ];

  ({
    ProviderContainer container,
    ThrowingNotificationService notifier,
    DayHistoryController controller,
  }) build(HistoryRepository repo) {
    final notifier = ThrowingNotificationService();
    notifier.shouldThrow = false; // sends succeed -- we just want to see it attempted
    final controller =
        DayHistoryController(repo: repo, settings: testTherapySettings());
    final container = ProviderContainer(overrides: [
      notificationServiceProvider.overrideWithValue(notifier),
      historyRepositoryProvider.overrideWithValue(repo),
      pumpSnapshotProvider
          .overrideWith((ref) => Stream.value(urgentLowSnapshot())),
      dayDataProvider.overrideWithValue(dayData()),
      livePredictionStateProvider.overrideWithValue(urgentLowState()),
      calibratedForecastsProvider.overrideWithValue(urgentForecast),
      rescueCarbAdviceProvider.overrideWithValue(null),
      // TASK-231: effectiveLowThresholdProvider (now read directly by onSnapshot)
      // otherwise pulls in recentAnnotationsProvider -> the real
      // dayHistoryControllerProvider, which outlives a single onSnapshot() call and
      // trips over container.dispose().
      recentAnnotationsProvider.overrideWith((ref) async => const []),
    ]);
    addTearDown(controller.dispose);
    addTearDown(container.dispose);
    return (container: container, notifier: notifier, controller: controller);
  }

  group('AC1: a saveCgm failure does not skip alert evaluation', () {
    test('ingestSnapshot throws (repo write failed) but the alert still fires',
        () async {
      appLog.clear();
      final repo = FaultInjectingHistoryRepository();
      repo.failOn('saveCgm');
      final env = build(repo);
      await env.container.read(pumpSnapshotProvider.future);

      // Mirrors lib/app.dart's exact composition: ingest (real controller, real
      // failing repo) chained with alert evaluation (real AlertService) via the
      // TASK-125 seam -- neither stage's failure should propagate, and a failed
      // ingest must not suppress the alert.
      await ingestThenEvaluateAlerts(
        ingest: () => env.controller.ingestSnapshot(urgentLowSnapshot()),
        evaluateAlerts: () => env.container.read(alertServiceProvider).onSnapshot(),
      );

      // Confirm the injected failure actually happened (not a false-positive pass
      // because saveCgm was never reached) -- ingestThenEvaluateAlerts logs exactly
      // this on an ingest failure.
      expect(
          appLog.entries.any((e) =>
              e.tag == 'snapshot' && e.message.contains('ingest failed')),
          isTrue,
          reason: 'the injected saveCgm failure should have been caught and logged');

      // The reading is "not silently lost": even though persisting it failed, the
      // urgent-low alert -- driven by the live snapshot/forecast, independent of
      // DayHistoryController's own (now-stale) state -- still fired.
      expect(env.notifier.shown, contains(NotificationCategory.urgentLow));
    });
  });

  group('AC2: a widget-channel throw does not abort ingest/alerts', () {
    const channel = MethodChannel('home_widget');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('no implementation for ${call.method}');
      });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('pushUpdate genuinely contains the widget-channel throw (not just an '
        'untested unawaited drop)', () async {
      appLog.clear();
      // TASK-270: unlike app.dart's fire-and-forget unawaited() call, AWAIT this
      // directly so the test actually observes what pushUpdate does with the
      // injected MissingPluginException -- if HomeWidgetService's own try/catch
      // (TASK-208) were removed, this await would throw and the test would fail
      // outright, instead of the unawaited-drop silently hiding it either way.
      await HomeWidgetService().pushUpdate(urgentLowSnapshot(), GlucoseUnit.mmol);
      expect(
        appLog.entries
            .any((e) => e.tag == 'home_widget' && e.level == LogLevel.error),
        isTrue,
        reason: 'the injected MethodChannel throw should have been caught and '
            'logged, not silently swallowed with no trace',
      );
    });

    test('pushUpdate throwing (fire-and-forget, unawaited like app.dart) does not '
        'block the following ingest+alerts call', () async {
      final env = build(FaultInjectingHistoryRepository());
      await env.container.read(pumpSnapshotProvider.future);

      // app.dart calls this WITHOUT awaiting it before the ingest/alerts chain --
      // reproduce that exact ordering. The test above already proves pushUpdate
      // contains the throw for real; this test is purely structural (unawaited()
      // can never block by definition, regardless of what's inside the Future).
      unawaited(HomeWidgetService().pushUpdate(urgentLowSnapshot(), GlucoseUnit.mmol));

      await ingestThenEvaluateAlerts(
        ingest: () => env.controller.ingestSnapshot(urgentLowSnapshot()),
        evaluateAlerts: () => env.container.read(alertServiceProvider).onSnapshot(),
      );

      expect(env.notifier.shown, contains(NotificationCategory.urgentLow));
    });
  });

  group('AC3: a Nightscout upload throw is contained', () {
    NightscoutClient throwingHttpClient() => NightscoutClient(
          const NightscoutConfig(
              baseUrl: 'https://example.invalid',
              apiSecret: 'xxxxxxxxxxxx',
              enabled: true),
          httpClient: _ThrowingHttpClient(),
        );

    test('a network-level failure is contained inside NightscoutClient itself '
        '(the internal swallow -- _postJson\'s own try/catch)', () async {
      // This layer's guarantee: uploadEntries() never throws for an HTTP-level
      // failure. It does NOT exercise app.dart's unawaitedLogged wrapper at all --
      // _postJson's catch fires first every time, so this alone can't tell whether
      // the wrapper actually does anything. See the next test for that.
      await expectLater(
        throwingHttpClient().uploadEntries(
            [CgmSample(time: now, mgdl: 100, trend: GlucoseTrend.flat)]),
        completes,
      );
    });

    test(
        'a serialisation failure reaches unawaitedLogged\'s catchError -- the '
        'app-root wrapper, not the client\'s internal swallow', () async {
      appLog.clear();
      // TASK-270: entryFromCgm calls sample.mgdl.round(), which throws
      // UnsupportedError for NaN -- this happens in uploadEntries' own List.map,
      // BEFORE _postJson's try/catch is ever reached (the http client here is
      // irrelevant; the request is never even built). A genuine caller-side bug
      // like this is exactly the class the ticket calls out: the OLD test's
      // _ThrowingHttpClient could never reach this path, so unawaitedLogged's own
      // containment was never actually pinned.
      final badSample =
          CgmSample(time: now, mgdl: double.nan, trend: GlucoseTrend.flat);

      unawaitedLogged(throwingHttpClient().uploadEntries([badSample]),
          'nightscout', 'entry upload failed');
      await Future<void>.delayed(Duration.zero);

      expect(
        appLog.entries.where((e) =>
            e.level == LogLevel.error &&
            e.tag == 'nightscout' &&
            e.message == 'entry upload failed'),
        isNotEmpty,
        reason: 'unawaitedLogged\'s catchError should have caught the round() '
            'throw from the malformed sample -- if it didn\'t, this would be an '
            'unhandled async error instead',
      );
    });

    test('the sibling ingest+alerts chain still fires even when a concurrent '
        'Nightscout upload throws', () async {
      final env = build(FaultInjectingHistoryRepository());
      await env.container.read(pumpSnapshotProvider.future);
      final badSample =
          CgmSample(time: now, mgdl: double.nan, trend: GlucoseTrend.flat);

      // Same ordering as app.dart: fire the (failing) upload, unawaited, then run
      // the ingest/alerts chain -- the point is that this independent subsystem
      // is provably unaffected, not just that the outer call "completed".
      unawaitedLogged(throwingHttpClient().uploadEntries([badSample]),
          'nightscout', 'entry upload failed');
      await ingestThenEvaluateAlerts(
        ingest: () => env.controller.ingestSnapshot(urgentLowSnapshot()),
        evaluateAlerts: () => env.container.read(alertServiceProvider).onSnapshot(),
      );

      expect(env.notifier.shown, contains(NotificationCategory.urgentLow));
    });
  });
}
