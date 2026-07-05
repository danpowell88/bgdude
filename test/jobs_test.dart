import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/dev/sim_data.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // Anchor the simulated day to real "now" so it lands in the trainer's read window.
    now = DateTime.now();
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
}
