import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/dev/sim_data.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/ml/health_features.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/faults.dart';

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
    // window — AppJobs uses the wall clock internally until TASK-39 injects it.
    now = DateTime.now(); // now-ok: production reads the wall clock (TASK-39)
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
    // A matured prediction (made 12h ago) gets an actual filled in from stored CGM.
    await repo.savePrediction(StoredPrediction(
      madeAt: now.subtract(const Duration(hours: 12)),
      horizonMinutes: 30,
      predictedMgdl: 140,
      lowerMgdl: 120,
      upperMgdl: 160,
      modelId: 'deterministic',
    ));
    final updated = await repo.reconcilePredictions(now);
    expect(updated, 1);
  });

  test('runStartup completes without throwing', () async {
    final jobs = container.read(appJobsProvider);
    await expectLater(jobs.runStartup(), completes);
  });

  // TASK-213: runStartup's per-job try/catch isolation (lib/state/startup_jobs.dart) is
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
}
