/// The alert_events table, its v4→v5 migration, and the repository round-trip
/// (issue #171).
///
/// The migration test matters more than it looks: it is the only thing standing
/// between a schema bump and an existing user's encrypted database failing to open
/// on upgrade. Follows cgm_calibration_test's precedent of building the OLD schema by
/// hand and letting the real migration run, rather than trusting that a fresh v5
/// database works.
library;

import 'package:bgdude/data/database.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/insights/alarm_fatigue.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('schema v4 → v5 migration', () {
    test('adds alert_events to an existing database without touching its data',
        () async {
      // A v4 database by hand, carrying a row we expect to survive untouched.
      final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
        raw.execute('''
          CREATE TABLE cgm_readings (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            time INTEGER NOT NULL,
            mgdl REAL NOT NULL,
            trend INTEGER NOT NULL DEFAULT 7,
            sensor_warmup INTEGER NOT NULL DEFAULT 0,
            compression_low INTEGER NOT NULL DEFAULT 0,
            is_calibration INTEGER NOT NULL DEFAULT 0,
            source TEXT NOT NULL DEFAULT 'sensor',
            UNIQUE(time)
          );
        ''');
        raw.execute('''
          CREATE TABLE bolus_events (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            time INTEGER NOT NULL, units REAL NOT NULL,
            carbs_grams REAL, UNIQUE(time, units));
        ''');
        raw.execute('''
          CREATE TABLE carb_entries (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            time INTEGER NOT NULL, grams REAL NOT NULL,
            absorption_minutes INTEGER NOT NULL DEFAULT 180, UNIQUE(time, grams));
        ''');
        raw.execute('''
          CREATE TABLE basal_segments (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            start INTEGER NOT NULL, end INTEGER NOT NULL,
            units_per_hour REAL NOT NULL, UNIQUE(start));
        ''');
        // Drift stores DateTime as unix SECONDS, not milliseconds — a ms value here
        // lands in the year 57000 and silently falls outside any sane query window.
        raw.execute(
            "INSERT INTO cgm_readings (time, mgdl) VALUES (1751800000, 120.0)");
        raw.execute('PRAGMA user_version = 4');
      }));
      addTearDown(db.close);

      // Opening runs the migration.
      final repo = DriftHistoryRepository(db);
      final at = DateTime(2026, 7, 18, 3, 15);
      await repo.saveAlertEvent(
          AlertEvent(category: NotificationCategory.urgentLow, firedAt: at));

      final events = await repo.alertEvents(
          at.subtract(const Duration(days: 1)), at.add(const Duration(days: 1)));
      expect(events, hasLength(1),
          reason: 'the new table must be usable straight after the migration');

      // ...and the pre-existing row is still there, unmodified. A migration that
      // creates the table but loses history would pass a table-exists check.
      final cgm = await repo.cgm(
          DateTime.fromMillisecondsSinceEpoch(1751700000 * 1000),
          DateTime.fromMillisecondsSinceEpoch(1751900000 * 1000));
      expect(cgm, hasLength(1));
      expect(cgm.single.mgdl, 120.0);
    });

    test('a fresh database is created at v5 with the table present', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftHistoryRepository(db);
      final at = DateTime(2026, 7, 18, 12);

      await repo.saveAlertEvent(
          AlertEvent(category: NotificationCategory.predictedLow, firedAt: at));

      expect(
        await repo.alertEvents(
            at.subtract(const Duration(hours: 1)), at.add(const Duration(hours: 1))),
        hasLength(1),
      );
    });
  });

  group('repository round-trip', () {
    test('events come back in the window, oldest first, category intact', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftHistoryRepository(db);
      final base = DateTime(2026, 7, 18, 12);

      await repo.saveAlertEvent(AlertEvent(
          category: NotificationCategory.predictedHigh,
          firedAt: base.add(const Duration(hours: 2))));
      await repo.saveAlertEvent(
          AlertEvent(category: NotificationCategory.urgentLow, firedAt: base));
      // Outside the queried window.
      await repo.saveAlertEvent(AlertEvent(
          category: NotificationCategory.missedBolus,
          firedAt: base.subtract(const Duration(days: 5))));

      final events = await repo.alertEvents(
          base.subtract(const Duration(hours: 1)),
          base.add(const Duration(hours: 3)));

      expect(events.map((e) => e.category).toList(), [
        NotificationCategory.urgentLow,
        NotificationCategory.predictedHigh,
      ]);
      expect(events.first.firedAt, base);
    });

    test('the same category firing repeatedly is kept as separate rows', () async {
      // Append-only is the point — collapsing duplicates would destroy exactly the
      // repeat-frequency signal alarm-fatigue analytics exists to measure.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftHistoryRepository(db);
      final base = DateTime(2026, 7, 18, 12);

      for (var i = 0; i < 5; i++) {
        await repo.saveAlertEvent(AlertEvent(
            category: NotificationCategory.urgentLow,
            firedAt: base.add(Duration(minutes: i * 30))));
      }

      final events = await repo.alertEvents(
          base.subtract(const Duration(hours: 1)), base.add(const Duration(days: 1)));
      expect(events, hasLength(5));
    });
  });

  group('the in-memory repository matches', () {
    test('round-trips and windows the same way as drift', () async {
      final repo = InMemoryHistoryRepository();
      final base = DateTime(2026, 7, 18, 12);

      await repo.saveAlertEvent(
          AlertEvent(category: NotificationCategory.urgentLow, firedAt: base));
      await repo.saveAlertEvent(AlertEvent(
          category: NotificationCategory.predictedLow,
          firedAt: base.subtract(const Duration(days: 30))));

      final events = await repo.alertEvents(
          base.subtract(const Duration(days: 1)), base.add(const Duration(days: 1)));

      // Tests run against the in-memory repo everywhere, so a divergence here would
      // make every one of them prove something about a store production never uses.
      expect(events, hasLength(1));
      expect(events.single.category, NotificationCategory.urgentLow);
    });
  });
}
