import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/database.dart';
import 'package:bgdude/data/health_sync.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-62: pruneOldData drops stale predictions (>90d) and health (>180d) but keeps all
/// glucose/insulin history (the training corpus).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftHistoryRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftHistoryRepository(db);
  });
  tearDown(() => db.close());

  test('prunes old predictions + health, keeps CGM/insulin', () async {
    final now = DateTime(2026, 7, 7, 12);
    final old = now.subtract(const Duration(days: 200));
    final recent = now.subtract(const Duration(days: 30));

    // A very old CGM reading + bolus that must survive (training corpus).
    await repo.saveCgm([CgmSample(time: old, mgdl: 120)]);
    await repo.saveBolus(BolusEvent(time: old, units: 3));
    // Health: one old (>180d), one recent.
    await repo.saveHealth([
      HealthSample(time: old, type: HealthMetric.sleepHours, value: 7),
      HealthSample(time: recent, type: HealthMetric.sleepHours, value: 8),
    ]);
    // Predictions: one old (>90d), one recent.
    await repo.savePrediction(StoredPrediction(
        madeAt: now.subtract(const Duration(days: 120)),
        horizonMinutes: 30, predictedMgdl: 120, lowerMgdl: 100, upperMgdl: 140,
        modelId: 'test'));
    await repo.savePrediction(StoredPrediction(
        madeAt: recent, horizonMinutes: 30, predictedMgdl: 120,
        lowerMgdl: 100, upperMgdl: 140, modelId: 'test'));

    final deleted = await repo.pruneOldData(now);
    expect(deleted, 2); // one old prediction + one old health sample

    // Corpus intact.
    final cgm = await repo.cgm(old.subtract(const Duration(days: 1)), now);
    expect(cgm, hasLength(1));
    final boluses = await repo.boluses(old.subtract(const Duration(days: 1)), now);
    expect(boluses, hasLength(1));
    // Only the recent health + prediction remain.
    final health = await repo.health(old.subtract(const Duration(days: 1)), now);
    expect(health, hasLength(1));
    final preds = await repo.predictions(old.subtract(const Duration(days: 1)), now);
    expect(preds, hasLength(1));
  });
}
