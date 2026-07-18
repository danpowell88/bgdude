import 'dart:convert';
import 'dart:io';

import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/database.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/dev/sim_data.dart';
import 'package:bgdude/insights/exercise_mode.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/insights/workout_classifier.dart';
import 'package:bgdude/ml/drift_detector.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:bgdude/ml/health_features.dart';
import 'package:bgdude/state/forecast_providers.dart';
import 'package:bgdude/state/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/faults.dart';

/// A [ResidualModel] with a fixed, known-in-advance per-horizon trained sigma, so
/// the TASK-138 drift-ratio tests below don't depend on what a real training run
/// happens to converge to.
class _FixedResidualModel implements ResidualModel {
  const _FixedResidualModel(this._sigmas);
  final Map<int, double> _sigmas;

  @override
  bool get isTrained => true;

  @override
  ({double residual, double sigma}) correct({
    required List<double> features,
    required int horizonMinutes,
  }) =>
      (residual: 0.0, sigma: _sigmas[horizonMinutes] ?? fallbackSigma(horizonMinutes));

  @override
  double? trainingSigma(int horizonMinutes) => _sigmas[horizonMinutes];
}

/// Wraps a [_FixedResidualModel] as the live model without waiting on (or racing)
/// the real async restore-from-disk -- mirrors the exact seam
/// ForecasterModelController exposes for this in forecaster_service_test.dart's
/// "a late restore never clobbers a newer in-memory model" test.
class _FixedModelController extends ForecasterModelController {
  _FixedModelController(ResidualModel model) {
    debugMarkNewerLocalModel();
    state = model;
  }
}

/// Exercises the background jobs (AppJobs) end-to-end against an in-memory repository
/// seeded with a simulated day — verifying they run without throwing and that the
/// forecaster actually trains from real stored history.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryHistoryRepository repo;
  late ProviderContainer container;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = InMemoryHistoryRepository();
    // Anchor the simulated day to real "now" so it lands in the trainer's read
    // window — AppJobs uses the wall clock internally until it's injected.
    now = DateTime.now(); // now-ok: production reads the wall clock
    final day = SimulatedDay.generate(now: now, seed: 5);
    await repo.saveCgm(day.cgm);
    for (final b in day.boluses) {
      await repo.saveBolus(b);
    }
    for (final c in day.carbs) {
      await repo.saveCarb(c);
    }
    for (final s in day.basal) {
      await repo.saveBasal(s);
    }
    container = ProviderContainer(overrides: [
      historyRepositoryProvider.overrideWithValue(repo),
      notificationServiceProvider.overrideWithValue(NotificationService()),
      devModeProvider.overrideWith((ref) => false),
      // Give the trainer the sim's therapy so residuals are consistent.
      therapySettingsProvider.overrideWith((ref) => TherapyNotifier()),
    ]);
  });

  tearDown(() => container.dispose());

  test('forecaster trains from seeded history', () async {
    final jobs = container.read(appJobsProvider);
    final outcome = await jobs.trainForecaster();
    expect(outcome.trained, isTrue);
    expect(outcome.trainSamples, greaterThan(150));
  });

  test('prediction reconciliation runs and logs are safe', () async {
    // A matured prediction gets an actual filled in from stored CGM.
    //
    // Issue #383: this used to target `now - 11h30m` and rely on whatever the
    // simulated day happened to have there. `reconcilePredictions` discards
    // artifacts (`!sensorWarmup && !compressionLow && mgdl > 0`), and sim_data
    // injects a compression low at the CALENDAR time 03:10. Since the target sat
    // at a fixed offset from the wall clock, the two aligned for ~25 minutes every
    // day (runner-local 14:35-15:00), scoring 0 and failing the suite on unrelated
    // PRs. Deterministic given the clock, so it read as a flake but was not one.
    //
    // Anchoring 30 days back puts the scenario outside the generated day entirely
    // ([now-24h, now]), so no artifact can ever land on it and the seeded reading
    // below cannot collide with a generated one — note InMemoryHistoryRepository
    // .saveCgm keeps the FIRST sample for a timestamp, so a colliding seed would
    // be silently dropped rather than winning the slot.
    final targetTime = now.subtract(const Duration(days: 30));
    await repo.saveCgm([CgmSample(time: targetTime, mgdl: 138)]);
    await repo.savePrediction(StoredPrediction(
      madeAt: targetTime.subtract(const Duration(minutes: 30)),
      horizonMinutes: 30,
      predictedMgdl: 140,
      lowerMgdl: 120,
      upperMgdl: 160,
      modelId: 'deterministic',
    ));

    final updated = await repo.reconcilePredictions(now);

    expect(updated, 1);
    // Assert the value too: "1 row touched" alone would pass even if the wrong
    // reading were matched, which is the failure the ±5-min window can produce.
    final scored = await repo.predictions(
        targetTime.subtract(const Duration(days: 1)), now);
    expect(scored.single.actualMgdl, 138);
  });

  test('runStartup completes without throwing', () async {
    final jobs = container.read(appJobsProvider);
    await expectLater(jobs.runStartup(), completes);
  });

  // runStartup's per-job try/catch isolation (lib/state/startup_jobs.dart) is
  // load-bearing but was only ever pinned at the "completes without throwing" level --
  // nothing proved that a failing job's INDEPENDENT neighbours still did their real work.
  group('per-job failure isolation', () {
    test('a failing health sync does not stop forecaster training (a later, '
        'independent job)', () async {
      final c = ProviderContainer(overrides: [
        historyRepositoryProvider.overrideWithValue(repo),
        notificationServiceProvider.overrideWithValue(NotificationService()),
        devModeProvider.overrideWith((ref) => false),
        therapySettingsProvider.overrideWith((ref) => TherapyNotifier()),
        healthSyncServiceProvider.overrideWithValue(ThrowingHealthSyncService()),
      ]);
      addTearDown(c.dispose);

      final report = await c.read(appJobsProvider).runStartup();

      // The injected failure genuinely surfaced...
      expect(report.failures.map((f) => f.name), contains('syncHealth'));
      // ...but a later, unrelated job still did its real work: the forecaster
      // trained from the seeded history and recorded a model run.
      expect(await repo.modelRuns(), isNotEmpty);
    });

    test('health-permission-denied yields the zero-features contract end-to-end '
        'via livePredictionStateProvider', () async {
      final c = ProviderContainer(overrides: [
        historyRepositoryProvider.overrideWithValue(repo),
        notificationServiceProvider.overrideWithValue(NotificationService()),
        devModeProvider.overrideWith((ref) => false),
        therapySettingsProvider.overrideWith((ref) => TherapyNotifier()),
        healthSyncServiceProvider.overrideWithValue(ThrowingHealthSyncService()),
      ]);
      addTearDown(c.dispose);
      // Let the real DayHistoryController load the seeded CGM so
      // livePredictionStateProvider has a latest reading to build from.
      await c.read(dayHistoryControllerProvider.notifier).reload();

      await c.read(appJobsProvider).runStartup();

      final state = c.read(livePredictionStateProvider);
      expect(state, isNotNull);
      // syncHealth failed (permission denied), but refreshForecastHealthSampler -- a
      // separate, unconditional startup job right after it -- still ran and left the
      // sampler built from no data, which resolves to the exact same zero contract as
      // no sampler at all (HealthFeatureSampler([]).featuresAt(t) == zeros).
      expect(state!.healthFeatures, HealthFeatureSampler.zeros);
    });
  });

  group('forecast drift detection (TASK-138)', () {
    setUp(() => KvStore.useMemory());

    ProviderContainer buildContainer(ResidualModel model) =>
        ProviderContainer(overrides: [
          historyRepositoryProvider.overrideWithValue(repo),
          notificationServiceProvider.overrideWithValue(NotificationService()),
          devModeProvider.overrideWith((ref) => false),
          therapySettingsProvider.overrideWith((ref) => TherapyNotifier()),
          forecasterModelProvider
              .overrideWith((ref) => _FixedModelController(model)),
        ]);

    // 25 same-horizon predictions with a fixed, large error -- comfortably above
    // both UncertaintyCalibrator's minSamples floor (20) and the drift threshold
    // once compared against the small fixed trainingSigma used by these tests.
    Future<void> seedDriftingPredictions() async {
      for (var i = 0; i < 25; i++) {
        await repo.savePrediction(StoredPrediction(
          madeAt: now.subtract(Duration(hours: 1, minutes: i)),
          horizonMinutes: 30,
          predictedMgdl: 200,
          lowerMgdl: 180,
          upperMgdl: 220,
          modelId: 'test',
          actualMgdl: 100,
        ));
      }
    }

    test('a single drifting run raises the ratio but does not sustain the flag',
        () async {
      final c = buildContainer(const _FixedResidualModel({30: 5.0}));
      addTearDown(c.dispose);
      await seedDriftingPredictions();

      await c.read(appJobsProvider).updateRecentForecastError();

      final drift = c.read(forecastDriftProvider);
      expect(drift.ratios[30], greaterThanOrEqualTo(kDriftRatioThreshold));
      expect(drift.consecutiveDriftRuns, 1);
      expect(drift.sustained, isFalse);
    });

    test(
        'kSustainedDriftRuns consecutive drifting runs flags sustained drift, '
        'requests an out-of-band retrain, and the next model run logs the ratio',
        () async {
      final c = buildContainer(const _FixedResidualModel({30: 5.0}));
      addTearDown(c.dispose);
      await seedDriftingPredictions();
      final jobs = c.read(appJobsProvider);

      for (var i = 0; i < kSustainedDriftRuns; i++) {
        await jobs.updateRecentForecastError();
      }

      final drift = c.read(forecastDriftProvider);
      expect(drift.consecutiveDriftRuns, kSustainedDriftRuns);
      expect(drift.sustained, isTrue);

      // Out-of-band retrain requested: AppJobs._forecasterTrainStampKey reset so
      // runStartup's throttled trainForecaster job won't wait out its cooldown.
      final stamp = await KvStore.getString('forecaster_last_trained_at');
      expect(DateTime.parse(stamp!).year, 2000);

      // AC#3: the drift ratio that (potentially) triggered this training run is
      // logged into the saved model-run record.
      await jobs.trainForecaster();
      final runs = await repo.modelRuns();
      final metrics = jsonDecode(runs.last.metricsJson) as Map<String, dynamic>;
      expect(metrics['driftTriggered'], isTrue);
      expect((metrics['driftRatios'] as Map)['30'],
          greaterThanOrEqualTo(kDriftRatioThreshold));
    });

    test(
        'sustained-but-unfixable drift requests the out-of-band retrain only '
        'ONCE, not on every subsequent run it stays sustained (TASK-306)',
        () async {
      final c = buildContainer(const _FixedResidualModel({30: 5.0}));
      addTearDown(c.dispose);
      await seedDriftingPredictions();
      final jobs = c.read(appJobsProvider);

      for (var i = 0; i < kSustainedDriftRuns; i++) {
        await jobs.updateRecentForecastError();
      }
      expect(c.read(forecastDriftProvider).sustained, isTrue);

      // Simulate the requested retrain having actually run (trainForecaster
      // updates the stamp to "now" on success -- see the trainForecaster
      // StartupJob closure).
      final afterFirstTrigger = DateTime(2026, 1, 1);
      await KvStore.setString(
          'forecaster_last_trained_at', afterFirstTrigger.toIso8601String());

      // Drift is STILL sustained (nothing about the underlying predictions
      // changed) for several more reconciliation runs.
      for (var i = 0; i < 5; i++) {
        await jobs.updateRecentForecastError();
      }
      expect(c.read(forecastDriftProvider).sustained, isTrue,
          reason: 'drift genuinely never resolved');

      // A real retrain-triggering fix WOULD have reset the stamp back to
      // epoch again -- it must not have, since one was already requested for
      // this still-ongoing episode.
      final stamp = await KvStore.getString('forecaster_last_trained_at');
      expect(DateTime.parse(stamp!), afterFirstTrigger);
    });

    test(
        'a latch left over from an already-resolved episode does not block a '
        'genuinely fresh one', () async {
      final c = buildContainer(const _FixedResidualModel({30: 5.0}));
      addTearDown(c.dispose);
      final jobs = c.read(appJobsProvider);

      // Simulate a stale latch from a PRIOR (already-resolved) drift episode
      // that requested and completed its one retrain.
      await KvStore.setBool('forecast_drift_retrain_requested', true);
      await KvStore.setString(
          'forecaster_last_trained_at', DateTime(2026, 1, 1).toIso8601String());

      // A clean (low-error) reconciliation run -- the episode genuinely
      // resolved -- must clear that stale latch.
      for (var i = 0; i < 25; i++) {
        await repo.savePrediction(StoredPrediction(
          madeAt: now.subtract(Duration(minutes: 30 + i)),
          horizonMinutes: 30,
          predictedMgdl: 100,
          lowerMgdl: 90,
          upperMgdl: 110,
          modelId: 'test',
          actualMgdl: 100.1,
        ));
      }
      await jobs.updateRecentForecastError();
      expect(c.read(forecastDriftProvider).sustained, isFalse);

      // A genuinely NEW drift episode must be free to request its own
      // retrain -- the earlier episode's latch must not still be blocking it.
      await seedDriftingPredictions();
      for (var i = 0; i < kSustainedDriftRuns; i++) {
        await jobs.updateRecentForecastError();
      }
      expect(c.read(forecastDriftProvider).sustained, isTrue);
      final stamp = await KvStore.getString('forecaster_last_trained_at');
      expect(DateTime.parse(stamp!).year, 2000);
    });
  });

  group('announceExercise notification gating (TASK-305)', () {
    setUp(() => KvStore.useMemory());

    ProviderContainer buildContainer(NotificationService notifications) =>
        ProviderContainer(overrides: [
          historyRepositoryProvider.overrideWithValue(repo),
          notificationServiceProvider.overrideWithValue(notifications),
          devModeProvider.overrideWith((ref) => false),
          therapySettingsProvider.overrideWith((ref) => TherapyNotifier()),
        ]);

    final plan = ExercisePlan(
      startAt: DateTime.now(), // now-ok: only the plan's relative fields matter
      durationMinutes: 45,
      type: WorkoutType.aerobic, // raisesHypoRisk == true
    );

    test('notifies once the plan actually persists', () async {
      final notifications = NoopNotificationService();
      final c = buildContainer(notifications);
      addTearDown(c.dispose);

      await c.read(appJobsProvider).announceExercise(plan);

      expect(notifications.shown, contains(NotificationCategory.overnightLowRisk));
    });

    test(
        'does not notify when the persist fails -- the low-alert threshold was '
        'never actually raised, so saying it was would be a false signal',
        () async {
      final notifications = NoopNotificationService();
      final c = buildContainer(notifications);
      addTearDown(c.dispose);
      final unopenable = File('${Directory.systemTemp.path}/${'u' * 300}.db');
      KvStore.init(AppDatabase(NativeDatabase(unopenable)));

      await c.read(appJobsProvider).announceExercise(plan);

      expect(notifications.shown, isEmpty);
      expect(c.read(exercisePlanProvider), isNull,
          reason: 'the write failed -- no plan should be considered active');
    });
  });
}
