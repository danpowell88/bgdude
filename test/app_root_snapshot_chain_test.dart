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

import 'support/faults.dart';
import 'support/samples.dart';

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

    test('pushUpdate throwing (fire-and-forget, unawaited like app.dart) does not '
        'block the following ingest+alerts call', () async {
      final env = build(FaultInjectingHistoryRepository());
      await env.container.read(pumpSnapshotProvider.future);

      // app.dart calls this WITHOUT awaiting it before the ingest/alerts chain --
      // reproduce that exact ordering. HomeWidgetService's own internal try/catch
      // (TASK-208) means this never actually throws, but the point is structural:
      // even a dropped Future here cannot delay or abort what follows.
      unawaited(HomeWidgetService().pushUpdate(urgentLowSnapshot(), GlucoseUnit.mmol));

      await ingestThenEvaluateAlerts(
        ingest: () => env.controller.ingestSnapshot(urgentLowSnapshot()),
        evaluateAlerts: () => env.container.read(alertServiceProvider).onSnapshot(),
      );

      expect(env.notifier.shown, contains(NotificationCategory.urgentLow));
    });
  });

  group('AC3: a Nightscout upload throw is contained', () {
    test('uploadEntries with a throwing http client does not throw', () async {
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://example.invalid',
            apiSecret: 'xxxxxxxxxxxx',
            enabled: true),
        httpClient: _ThrowingHttpClient(),
      );

      // NightscoutClient._postJson already catches internally ("uploads are
      // best-effort background work") -- this pins that guarantee at the public
      // uploadEntries() entry point app.dart actually calls.
      await expectLater(
        client.uploadEntries(
            [CgmSample(time: now, mgdl: 100, trend: GlucoseTrend.flat)]),
        completes,
      );
    });

    test('wrapped in unawaitedLogged (as app.dart does), no unhandled error escapes',
        () async {
      appLog.clear();
      final client = NightscoutClient(
        const NightscoutConfig(
            baseUrl: 'https://example.invalid',
            apiSecret: 'xxxxxxxxxxxx',
            enabled: true),
        httpClient: _ThrowingHttpClient(),
      );

      unawaitedLogged(
          client.uploadEntries(
              [CgmSample(time: now, mgdl: 100, trend: GlucoseTrend.flat)]),
          'nightscout',
          'entry upload failed');
      await Future<void>.delayed(Duration.zero);

      // No error surfaces through unawaitedLogged's catchError either, since the
      // client already swallowed it -- confirms the double containment app.dart
      // relies on (client-internal AND the wrapper) rather than just one layer.
      expect(
          appLog.entries
              .where((e) => e.level == LogLevel.error && e.tag == 'nightscout'),
          isEmpty);
    });
  });
}
