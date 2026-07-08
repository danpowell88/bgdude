/// Encrypted local time-series store (drift + SQLCipher).
///
/// All health/pump data lives here, AES-256 encrypted at rest via SQLCipher. Tables are
/// timestamp-indexed for the range scans the analytics engine does. Run codegen to
/// produce `database.g.dart`:
///   dart run build_runner build --delete-conflicting-outputs
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/open.dart';

import 'meal_tables.dart';

part 'database.g.dart';

/// Thrown when the on-disk database's schema version is NEWER than this build's
/// [AppDatabase.schemaVersion] (TASK-199) — an older APK opening a database a newer
/// build already migrated (e.g. a sideload rollback). Drift's `onUpgrade` runs for
/// both upgrades AND downgrades (there is no separate `onDowngrade` in this drift
/// version), so without an explicit guard a downgrade would silently fall through
/// every `if (from < N)` migration step, do nothing, and let drift stamp
/// `user_version` down to this build's (older) schemaVersion anyway — corrupting the
/// version marker against a schema this code has never seen and doesn't understand.
class DatabaseDowngradeException implements Exception {
  const DatabaseDowngradeException({required this.from, required this.to});

  /// The on-disk schema version (newer than this build).
  final int from;

  /// This build's [AppDatabase.schemaVersion] (older than what's on disk).
  final int to;

  @override
  String toString() =>
      'DatabaseDowngradeException: the database is at schema version $from, but '
      'this app build only understands up to version $to — it was likely created '
      'by a newer version of the app. Update the app to use this data; installing '
      'an older build over it is not supported.';
}

@DataClassName('CgmRow')
class CgmReadings extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get time => dateTime()();
  RealColumn get mgdl => real()();
  IntColumn get trend => integer().withDefault(const Constant(7))(); // GlucoseTrend.index
  BoolColumn get sensorWarmup => boolean().withDefault(const Constant(false))();
  BoolColumn get compressionLow => boolean().withDefault(const Constant(false))();

  /// A calibration finger-prick (excluded from metrics/training) — schema v3 (TASK-9).
  BoolColumn get isCalibration => boolean().withDefault(const Constant(false))();

  /// 'sensor' | 'meter'. Sensor rows own their time slot; meter rows never overwrite them.
  TextColumn get source => text().withDefault(const Constant('sensor'))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {time},
      ];
}

@DataClassName('BolusRow')
class BolusEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get time => dateTime()();
  RealColumn get units => real()();
  RealColumn get carbsGrams => real().withDefault(const Constant(0))();
  BoolColumn get isExtended => boolean().withDefault(const Constant(false))();
  IntColumn get durationMinutes => integer().withDefault(const Constant(0))();
  BoolColumn get isAutomatic => boolean().withDefault(const Constant(false))();

  // A bolus is identified by its time + amount, so re-reading pump history (e.g. after a
  // restart) upserts rather than double-counting IOB/TDD (TASK-10).
  @override
  List<Set<Column>> get uniqueKeys => [
        {time, units},
      ];
}

@DataClassName('BasalRow')
class BasalSegments extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime()();
  RealColumn get unitsPerHour => real()();

  // One segment per start time; a re-observed segment updates its end/rate (TASK-10).
  @override
  List<Set<Column>> get uniqueKeys => [
        {start},
      ];
}

@DataClassName('CarbRow')
class CarbEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get time => dateTime()();
  RealColumn get grams => real()();
  IntColumn get absorptionMinutes => integer().withDefault(const Constant(180))();
  TextColumn get source => text().withDefault(const Constant('user'))();

  // Same time + grams is the same carb entry (TASK-10).
  @override
  List<Set<Column>> get uniqueKeys => [
        {time, grams},
      ];
}

@DataClassName('HealthRow')
class HealthSamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get time => dateTime()();
  TextColumn get type => text()(); // 'sleep' | 'hrv' | 'restingHr' | 'steps' | 'exercise'
  RealColumn get value => real()();
  TextColumn get meta => text().withDefault(const Constant('{}'))(); // JSON blob
}

@DataClassName('AnnotationRow')
class Annotations extends Table {
  TextColumn get id => text()();
  IntColumn get kind => integer()(); // AnnotationKind.index
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime()();
  RealColumn get carbsGrams => real().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
  RealColumn get confidence => real().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PredictionRow')
class Predictions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get madeAt => dateTime()();
  IntColumn get horizonMinutes => integer()();
  RealColumn get predictedMgdl => real()();
  RealColumn get lowerMgdl => real()();
  RealColumn get upperMgdl => real()();
  RealColumn get actualMgdl => real().nullable()(); // filled in later for eval
  TextColumn get modelId => text().withDefault(const Constant('deterministic'))();
}

/// Encrypted key-value store for app state that used to live in SharedPreferences
/// (therapy profile, illness/device state, meals, model blob, goals…) — consolidated
/// here so it is AES-256 encrypted at rest like the rest of the health data.
@DataClassName('AppKvRow')
class AppKv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('ModelRunRow')
class ModelRuns extends Table {
  TextColumn get id => text()();
  TextColumn get stage => text()(); // ModelStage.name
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get trainedOnDays => integer()();
  TextColumn get metricsJson => text().withDefault(const Constant('{}'))();
  TextColumn get weightsJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    CgmReadings,
    BolusEvents,
    BasalSegments,
    CarbEntries,
    HealthSamples,
    Annotations,
    Predictions,
    ModelRuns,
    SavedMeals,
    AppKv,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 4;

  /// Read a value from the encrypted key-value store.
  Future<String?> readKv(String key) async {
    final row = await (select(appKv)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Write a value to the encrypted key-value store.
  Future<void> writeKv(String key, String value) =>
      into(appKv).insertOnConflictUpdate(
          AppKvCompanion.insert(key: key, value: value));

  Future<void> saveModelRunRow(ModelRunsCompanion row) =>
      into(modelRuns).insertOnConflictUpdate(row);

  Future<List<ModelRunRow>> allModelRuns() =>
      (select(modelRuns)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // TASK-199: see DatabaseDowngradeException's doc comment — this MUST be
          // the first check, before any `if (from < N)` migration step runs.
          if (from > to) throw DatabaseDowngradeException(from: from, to: to);
          if (from < 2) await m.createTable(appKv);
          if (from < 3) {
            // TASK-9: distinguish sensor readings from finger-prick / calibration ones.
            await m.addColumn(cgmReadings, cgmReadings.isCalibration);
            await m.addColumn(cgmReadings, cgmReadings.source);
          }
          if (from < 4) {
            // TASK-10: dedupe bolus/carb/basal so re-read history can't double-count.
            // Drop existing duplicates (keep the lowest id), then enforce uniqueness with an
            // index (a fresh v4 db gets the table-level UNIQUE constraint via uniqueKeys).
            await customStatement(
                'DELETE FROM bolus_events WHERE id NOT IN '
                '(SELECT MIN(id) FROM bolus_events GROUP BY time, units)');
            await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS '
                'uq_bolus_time_units ON bolus_events(time, units)');
            await customStatement(
                'DELETE FROM carb_entries WHERE id NOT IN '
                '(SELECT MIN(id) FROM carb_entries GROUP BY time, grams)');
            await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS '
                'uq_carb_time_grams ON carb_entries(time, grams)');
            await customStatement(
                'DELETE FROM basal_segments WHERE id NOT IN '
                '(SELECT MIN(id) FROM basal_segments GROUP BY start)');
            await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS '
                'uq_basal_start ON basal_segments(start)');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA foreign_keys=ON');
          // TASK-185: the WorkManager summary backstop (read-only, see
          // background_summary.dart) opens its own connection to the same WAL
          // file concurrently with the main isolate's writer; without a busy
          // timeout a reader that lands mid-checkpoint gets SQLITE_BUSY
          // immediately instead of waiting the brief contention out. This does
          // NOT make a second concurrent *writer* safe — drift's own multi-
          // instance warning still applies to that (see db_concurrency_test.dart).
          await customStatement('PRAGMA busy_timeout=5000');
        },
      );

  /// CGM readings in [from, to), ordered by time.
  Future<List<CgmRow>> cgmBetween(DateTime from, DateTime to) {
    return (select(cgmReadings)
          ..where((t) => t.time.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm(expression: t.time)]))
        .get();
  }

  Future<void> upsertCgm(CgmReadingsCompanion row) =>
      into(cgmReadings).insertOnConflictUpdate(row);
}

/// The encrypted database's standard on-disk location.
Future<File> defaultDatabaseFile() async => File(p.join(
    (await getApplicationDocumentsDirectory()).path, 'bgdude_encrypted.db'));

/// TASK-192/249: retires the encrypted database file so the next open starts fresh —
/// the destructive "reset storage" recovery action. Renames (never deletes) the file
/// and its WAL/shm/journal sidecars to a timestamped `.bak-<epoch>` path alongside
/// the original, rather than erasing them: a `keyOrHeaderCorrupt` verdict can't tell
/// a truly-corrupt file apart from a recoverable key mismatch, so destroying the
/// only copy of someone's glucose/insulin history on that guess isn't acceptable.
/// The stored passphrase is left as-is; a fresh empty file re-encrypts under the
/// same key next launch (callers doing a genuine key reset also clear the key via
/// `SecureKeyStore.forgetForReset`). [file] overrides the on-disk location for
/// tests, matching `openEncryptedDatabase`; production callers never pass it.
Future<void> retireDatabaseFile({File? file}) async {
  file ??= await defaultDatabaseFile();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  if (await file.exists()) await file.rename('${file.path}.bak-$stamp');
  for (final suffix in ['-wal', '-shm', '-journal']) {
    final side = File('${file.path}$suffix');
    if (await side.exists()) await side.rename('${side.path}.bak-$stamp');
  }
  await _pruneOldBackups(file, keepStamp: stamp);
}

/// TASK-254: a reset the user repeats (e.g. still troubleshooting) would otherwise
/// leave every past `.bak-<epoch>` copy of the (large, years-of-CGM-data) encrypted
/// DB on disk forever. Keeps only the just-created backup set (identified by
/// [keepStamp]) and deletes every OLDER `.bak-*` file for [file]'s base name and its
/// WAL/shm/journal sidecars -- one retained backup is enough to recover from the
/// most recent reset without accumulating unbounded copies.
Future<void> _pruneOldBackups(File file, {required int keepStamp}) async {
  final dir = file.parent;
  if (!await dir.exists()) return;
  final baseName = p.basename(file.path);
  final keepSuffix = '.bak-$keepStamp';
  await for (final entry in dir.list()) {
    if (entry is! File) continue;
    final name = p.basename(entry.path);
    if (!name.startsWith(baseName) || !name.contains('.bak-')) continue;
    if (name.endsWith(keepSuffix)) continue;
    try {
      await entry.delete();
    } catch (_) {
      // Best-effort cleanup -- a locked/already-gone file must not block the reset
      // that's already succeeded.
    }
  }
}

/// Opens the encrypted database. The passphrase is stored in the platform keystore via
/// flutter_secure_storage (see `data/secure_key.dart`) — never hard-coded. [file]
/// overrides the on-disk location (TASK-192 tests: point at a fixture file instead of
/// the real app documents directory); production callers never pass it.
LazyDatabase openEncryptedDatabase(String passphrase, {File? file}) {
  return LazyDatabase(() async {
    // Ensure the app uses the SQLCipher-enabled sqlite3, not the system one.
    open.overrideForAll(openCipherOnAndroid);

    final dbFile = file ?? await defaultDatabaseFile();

    return NativeDatabase.createInBackground(
      dbFile,
      isolateSetup: () async {
        open.overrideForAll(openCipherOnAndroid);
      },
      setup: (db) {
        // Apply the cipher key before any other statement.
        final escaped = passphrase.replaceAll("'", "''");
        db.execute("PRAGMA key = '$escaped';");
        // Verify cipher is active (throws if the lib isn't SQLCipher).
        final result = db.select('PRAGMA cipher_version;');
        if (result.isEmpty) {
          throw StateError('SQLCipher not active — refusing to store data unencrypted');
        }
      },
    );
  });
}
