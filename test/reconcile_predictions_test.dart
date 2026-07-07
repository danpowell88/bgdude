import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/database.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-42: prediction reconciliation runs off one CGM query + batched updates, and scores
/// each due prediction against the nearest reading. Exercises DriftHistoryRepository on an
/// in-memory DB (AC#3, AC#4).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftHistoryRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftHistoryRepository(db);
  });
  tearDown(() => db.close());

  test('scores due predictions against the nearest reading, leaves future ones', () async {
    final base = DateTime(2026, 7, 7, 8);
    // CGM readings at t+30 (=140) and t+60 (=160).
    await repo.saveCgm([
      CgmSample(time: base.add(const Duration(minutes: 30)), mgdl: 140),
      CgmSample(time: base.add(const Duration(minutes: 60)), mgdl: 160),
    ]);
    // Two predictions whose targets have passed, one whose target is in the future.
    await repo.savePrediction(StoredPrediction(
        madeAt: base, horizonMinutes: 30, predictedMgdl: 135,
        lowerMgdl: 120, upperMgdl: 150, modelId: 'test'));
    await repo.savePrediction(StoredPrediction(
        madeAt: base, horizonMinutes: 60, predictedMgdl: 155,
        lowerMgdl: 140, upperMgdl: 170, modelId: 'test'));
    await repo.savePrediction(StoredPrediction(
        madeAt: base, horizonMinutes: 240, predictedMgdl: 120,
        lowerMgdl: 100, upperMgdl: 140, modelId: 'test'));

    // "Now" is t+90: the 30- and 60-min targets are due; the 240-min one is not.
    final updated = await repo.reconcilePredictions(base.add(const Duration(minutes: 90)));
    expect(updated, 2);

    final scored = await db.select(db.predictions).get();
    final byHorizon = {for (final r in scored) r.horizonMinutes: r.actualMgdl};
    expect(byHorizon[30], 140); // nearest reading to t+30
    expect(byHorizon[60], 160); // nearest reading to t+60
    expect(byHorizon[240], isNull); // not yet due — untouched

    // Idempotent: a second run has nothing left to score.
    final again = await repo.reconcilePredictions(base.add(const Duration(minutes: 90)));
    expect(again, 0);
  });

  test('a due prediction with no reading in the window is left unscored', () async {
    final base = DateTime(2026, 7, 7, 9);
    await repo.saveCgm([CgmSample(time: base, mgdl: 100)]); // far from the target
    await repo.savePrediction(StoredPrediction(
        madeAt: base, horizonMinutes: 30, predictedMgdl: 135,
        lowerMgdl: 120, upperMgdl: 150, modelId: 'test'));
    final updated = await repo.reconcilePredictions(base.add(const Duration(hours: 1)));
    expect(updated, 0);
  });

  test('TASK-133: a compression-low nadir is never chosen as ground truth',
      () async {
    final base = DateTime(2026, 7, 7, 2); // overnight — the classic case
    final target = base.add(const Duration(minutes: 30));
    await repo.saveCgm([
      // The artifact sits EXACTLY on the target time with a scary value...
      CgmSample(time: target, mgdl: 48, compressionLow: true),
      // ...while the real reading is 4 minutes later.
      CgmSample(time: target.add(const Duration(minutes: 4)), mgdl: 112),
    ]);
    await repo.savePrediction(StoredPrediction(
        madeAt: base, horizonMinutes: 30, predictedMgdl: 110,
        lowerMgdl: 95, upperMgdl: 125, modelId: 'test'));

    final updated =
        await repo.reconcilePredictions(base.add(const Duration(minutes: 60)));
    expect(updated, 1);
    final scored = await db.select(db.predictions).get();
    expect(scored.single.actualMgdl, 112,
        reason: 'the artifact must be skipped, not scored against');
  });

  test('TASK-133: reconciliation is skipped when only artifact rows exist',
      () async {
    final base = DateTime(2026, 7, 7, 2);
    final target = base.add(const Duration(minutes: 30));
    await repo.saveCgm([
      CgmSample(time: target, mgdl: 48, compressionLow: true),
      CgmSample(
          time: target.add(const Duration(minutes: 2)),
          mgdl: 90,
          sensorWarmup: true),
    ]);
    await repo.savePrediction(StoredPrediction(
        madeAt: base, horizonMinutes: 30, predictedMgdl: 110,
        lowerMgdl: 95, upperMgdl: 125, modelId: 'test'));

    final updated =
        await repo.reconcilePredictions(base.add(const Duration(minutes: 60)));
    expect(updated, 0);
    final scored = await db.select(db.predictions).get();
    expect(scored.single.actualMgdl, isNull,
        reason: 'better unscored than scored against an artifact');
  });
}
