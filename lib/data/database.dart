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
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

part 'database.g.dart';

@DataClassName('CgmRow')
class CgmReadings extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get time => dateTime()();
  RealColumn get mgdl => real()();
  IntColumn get trend => integer().withDefault(const Constant(7))(); // GlucoseTrend.index
  BoolColumn get sensorWarmup => boolean().withDefault(const Constant(false))();
  BoolColumn get compressionLow => boolean().withDefault(const Constant(false))();

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
}

@DataClassName('BasalRow')
class BasalSegments extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime()();
  RealColumn get unitsPerHour => real()();
}

@DataClassName('CarbRow')
class CarbEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get time => dateTime()();
  RealColumn get grams => real()();
  IntColumn get absorptionMinutes => integer().withDefault(const Constant(180))();
  TextColumn get source => text().withDefault(const Constant('user'))();
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA foreign_keys=ON');
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

/// Opens the encrypted database. The passphrase is stored in the platform keystore via
/// flutter_secure_storage (see `data/secure_key.dart`) — never hard-coded.
LazyDatabase openEncryptedDatabase(String passphrase) {
  return LazyDatabase(() async {
    // Ensure the app uses the SQLCipher-enabled sqlite3, not the system one.
    open.overrideForAll(openCipherOnAndroid);

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'bgdude_encrypted.db'));

    return NativeDatabase.createInBackground(
      file,
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
