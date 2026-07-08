import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/database.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// CGM calibration/source flag, the v2→v3 migration, and the guarantee that a
/// finger-prick reading never overwrites a sensor row and calibrations don't reach stats.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('schema v2 → v3 migration (AC#4)', () {
    test('adds isCalibration + source to existing rows without losing data', () async {
      // Build a v2 database by hand: the old cgm_readings shape and user_version = 2.
      final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
        raw.execute('''
          CREATE TABLE cgm_readings (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            time INTEGER NOT NULL,
            mgdl REAL NOT NULL,
            trend INTEGER NOT NULL DEFAULT 7,
            sensor_warmup INTEGER NOT NULL DEFAULT 0,
            compression_low INTEGER NOT NULL DEFAULT 0,
            UNIQUE(time)
          );
        ''');
        // The v4 dedupe step touches these tables, so they must exist at v2 too.
        raw.execute('''
          CREATE TABLE bolus_events (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, time INTEGER NOT NULL,
            units REAL NOT NULL, carbs_grams REAL NOT NULL DEFAULT 0,
            is_extended INTEGER NOT NULL DEFAULT 0, duration_minutes INTEGER NOT NULL DEFAULT 0,
            is_automatic INTEGER NOT NULL DEFAULT 0);
        ''');
        raw.execute('''
          CREATE TABLE carb_entries (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, time INTEGER NOT NULL,
            grams REAL NOT NULL, absorption_minutes INTEGER NOT NULL DEFAULT 180,
            source TEXT NOT NULL DEFAULT 'user');
        ''');
        raw.execute('''
          CREATE TABLE basal_segments (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, start INTEGER NOT NULL,
            "end" INTEGER NOT NULL, units_per_hour REAL NOT NULL);
        ''');
        raw.execute('INSERT INTO cgm_readings (time, mgdl) VALUES (1700000000, 120.0);');
        raw.execute('PRAGMA user_version = 2;');
      }));
      addTearDown(db.close);

      // Opening at schemaVersion 3 runs the migration; the old row must survive with the
      // new columns defaulted (sensor, not a calibration).
      final rows = await db.customSelect('SELECT * FROM cgm_readings').get();
      expect(rows, hasLength(1));
      expect(rows.single.data['is_calibration'], 0);
      expect(rows.single.data['source'], 'sensor');
      expect(rows.single.data['mgdl'], 120.0);
    });
  });

  group('finger-prick never overwrites a sensor row (AC#2)', () {
    test('a meter reading at the same time as a sensor row is ignored', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftHistoryRepository(db);
      final t = DateTime(2026, 7, 7, 8);

      await repo.saveCgm([CgmSample(time: t, mgdl: 120)]); // sensor
      await repo.saveCgm([
        CgmSample(
            time: t, mgdl: 300, source: GlucoseSource.meter, isCalibration: true),
      ]);

      final rows = await repo.cgm(t.subtract(const Duration(hours: 1)),
          t.add(const Duration(hours: 1)));
      expect(rows, hasLength(1));
      // The sensor value survived; the finger-prick did not clobber it.
      expect(rows.single.mgdl, 120);
      expect(rows.single.source, GlucoseSource.sensor);
    });

    test('a later sensor reading still updates its own time slot', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftHistoryRepository(db);
      final t = DateTime(2026, 7, 7, 9);
      await repo.saveCgm([CgmSample(time: t, mgdl: 100)]);
      await repo.saveCgm([CgmSample(time: t, mgdl: 140)]); // corrected sensor value
      final rows = await repo.cgm(t.subtract(const Duration(hours: 1)),
          t.add(const Duration(hours: 1)));
      expect(rows.single.mgdl, 140);
    });
  });

  test('calibrations are excluded from metrics (AC#3)', () {
    final base = DateTime(2026, 7, 7);
    final samples = [
      for (var i = 0; i < 10; i++)
        CgmSample(time: base.add(Duration(minutes: 5 * i)), mgdl: 120),
      // A calibration finger-prick that, if counted, would drag the mean up.
      CgmSample(
          time: base.add(const Duration(minutes: 52)),
          mgdl: 400,
          source: GlucoseSource.meter,
          isCalibration: true),
    ];
    final m = const MetricsCalculator().compute(samples);
    expect(m.readingCount, 10); // the calibration is not counted
    expect(m.meanMgdl, closeTo(120, 0.001)); // and does not move the mean
  });
}
