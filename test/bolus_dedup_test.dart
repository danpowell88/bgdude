import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/database.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/state/day_history_controller.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/samples.dart';

/// TASK-10: bolus/carb/basal inserts dedupe, and a live snapshot after a restart doesn't
/// re-insert the pump's already-saved last bolus.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('insert dedupe (AC#1)', () {
    late AppDatabase db;
    late DriftHistoryRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = DriftHistoryRepository(db);
    });
    tearDown(() => db.close());

    test('the same bolus saved twice is stored once', () async {
      final t = DateTime(2026, 7, 7, 8);
      await repo.saveBolus(BolusEvent(time: t, units: 4.5));
      await repo.saveBolus(BolusEvent(time: t, units: 4.5));
      final rows = await repo.boluses(
          t.subtract(const Duration(hours: 1)), t.add(const Duration(hours: 1)));
      expect(rows, hasLength(1));
    });

    test('the same carb entry saved twice is stored once', () async {
      final t = DateTime(2026, 7, 7, 9);
      await repo.saveCarb(CarbEntry(time: t, grams: 40));
      await repo.saveCarb(CarbEntry(time: t, grams: 40));
      final rows = await repo.carbs(
          t.subtract(const Duration(hours: 1)), t.add(const Duration(hours: 1)));
      expect(rows, hasLength(1));
    });

    test('a re-observed basal segment updates instead of duplicating', () async {
      final s = DateTime(2026, 7, 7, 10);
      await repo.saveBasal(
          BasalSegment(start: s, end: s.add(const Duration(hours: 1)), unitsPerHour: 0.8));
      await repo.saveBasal(
          BasalSegment(start: s, end: s.add(const Duration(hours: 2)), unitsPerHour: 0.9));
      final rows = await repo.basal(
          s.subtract(const Duration(hours: 1)), s.add(const Duration(hours: 3)));
      expect(rows, hasLength(1));
      expect(rows.single.unitsPerHour, 0.9); // the update won
    });
  });

  group('restart does not double-save the last bolus (AC#2/#3)', () {
    test('ingesting a snapshot for an already-saved bolus adds no duplicate', () async {
      final t = DateTime(2026, 7, 7, 8);
      // Simulate pre-restart persisted state: one bolus already in the store.
      final repo = InMemoryHistoryRepository();
      await repo.saveBolus(BolusEvent(time: t, units: 5.0));

      // A fresh controller (as after a restart) — _lastBolusTime starts null.
      final controller = DayHistoryController(
        repo: repo,
        settings: testTherapySettings(),
        clock: () => t.add(const Duration(minutes: 3)),
      );
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero); // let the constructor's reload settle

      // The pump reports its last bolus (the one already saved) alongside a CGM reading.
      await controller.ingestSnapshot(PumpSnapshot(
        time: t.add(const Duration(minutes: 3)),
        cgmMgdl: 120,
        cgmTime: t.add(const Duration(minutes: 3)),
        lastBolusUnits: 5.0,
        lastBolusTime: t,
      ));

      final boluses = await repo.boluses(
          t.subtract(const Duration(days: 1)), t.add(const Duration(days: 1)));
      expect(boluses, hasLength(1)); // not re-inserted
    });

    test('a genuinely new bolus in a snapshot is still saved', () async {
      final t = DateTime(2026, 7, 7, 8);
      final repo = InMemoryHistoryRepository();
      await repo.saveBolus(BolusEvent(time: t, units: 5.0));
      final controller = DayHistoryController(
        repo: repo,
        settings: testTherapySettings(),
        clock: () => t.add(const Duration(minutes: 30)),
      );
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      final t2 = t.add(const Duration(minutes: 20));
      await controller.ingestSnapshot(PumpSnapshot(
        time: t.add(const Duration(minutes: 30)),
        cgmMgdl: 130,
        cgmTime: t.add(const Duration(minutes: 30)),
        lastBolusUnits: 2.0,
        lastBolusTime: t2,
      ));

      final boluses = await repo.boluses(
          t.subtract(const Duration(days: 1)), t.add(const Duration(days: 1)));
      expect(boluses, hasLength(2)); // the new bolus was added
    });
  });
}
