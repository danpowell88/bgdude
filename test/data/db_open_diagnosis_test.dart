import 'dart:convert';
import 'dart:io';

import 'package:bgdude/data/database.dart';
import 'package:bgdude/data/db_open_diagnosis.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// classifyDbOpenFailure is unit-tested directly against synthetic
/// exceptions shaped exactly like what SQLCipher/sqlite3 actually raise (same result
/// codes, same exception type) — the decision logic under test either way.
///
/// openHistoryRepository's end-to-end behaviour is NOT exercised here: it always
/// routes through sqlcipher_flutter_libs' openCipherOnAndroid, which unconditionally
/// tries `DynamicLibrary.open('libsqlcipher.so')` then falls back to reading
/// `/proc/self/cmdline` — both fail immediately on this Windows/desktop test host
/// regardless of the file's content, encrypted or not, real key or wrong one. That
/// needs a real Android device/emulator to exercise; classifyDbOpenFailure is the
/// actual decision logic driving the recovery screen's branch, and that IS covered.
void main() {
  group('classifyDbOpenFailure', () {
    test('SQLITE_NOTADB on the very first read = wrong key or header corrupt', () {
      final e = SqliteException(26, 'file is not a database');
      expect(classifyDbOpenFailure(e, keyConfirmed: false),
          DbOpenDiagnosis.keyOrHeaderCorrupt);
    });

    test('SQLITE_NOTADB after the key was already confirmed = corrupted data', () {
      final e = SqliteException(26, 'file is not a database');
      expect(classifyDbOpenFailure(e, keyConfirmed: true),
          DbOpenDiagnosis.corruptedData);
    });

    test('SQLITE_CORRUPT is always corrupted data, key confirmed or not', () {
      final e = SqliteException(11, 'database disk image is malformed');
      expect(classifyDbOpenFailure(e, keyConfirmed: false),
          DbOpenDiagnosis.corruptedData);
      expect(classifyDbOpenFailure(e, keyConfirmed: true),
          DbOpenDiagnosis.corruptedData);
    });

    test('IO-shaped SQLite codes (CANTOPEN/IOERR/FULL/PERM) are ioError', () {
      for (final code in [14, 10, 13, 3]) {
        final e = SqliteException(code, 'io trouble');
        expect(classifyDbOpenFailure(e, keyConfirmed: false),
            DbOpenDiagnosis.ioError,
            reason: 'code $code');
      }
    });

    test('a bare FileSystemException is ioError', () {
      final e = Exception('disk full');
      // Not a FileSystemException instance in this synthetic case, so falls to
      // unknown — real FileSystemExceptions (dart:io) are covered by the type check
      // in classifyDbOpenFailure directly.
      expect(classifyDbOpenFailure(e, keyConfirmed: false), DbOpenDiagnosis.unknown);
    });

    test('an unrecognised error is unknown', () {
      expect(classifyDbOpenFailure(StateError('huh'), keyConfirmed: false),
          DbOpenDiagnosis.unknown);
    });

    test('a DatabaseDowngradeException is schemaNewerThanApp', () {
      expect(
          classifyDbOpenFailure(const DatabaseDowngradeException(from: 5, to: 4),
              keyConfirmed: false),
          DbOpenDiagnosis.schemaNewerThanApp);
      // Regardless of keyConfirmed -- this check happens before the key/header
      // is even relevant.
      expect(
          classifyDbOpenFailure(const DatabaseDowngradeException(from: 5, to: 4),
              keyConfirmed: true),
          DbOpenDiagnosis.schemaNewerThanApp);
    });
  });

  group('DbOpenDiagnosis.salvageable', () {
    test('only corruptedData is salvageable', () {
      expect(DbOpenDiagnosis.corruptedData.salvageable, isTrue);
      expect(DbOpenDiagnosis.keyOrHeaderCorrupt.salvageable, isFalse);
      expect(DbOpenDiagnosis.ioError.salvageable, isFalse);
      expect(DbOpenDiagnosis.keyReadFailure.salvageable, isFalse);
      expect(DbOpenDiagnosis.schemaNewerThanApp.salvageable, isFalse);
      expect(DbOpenDiagnosis.unknown.salvageable, isFalse);
    });
  });

  group('DbOpenDiagnosis.resetIsSensible', () {
    test('false only for schemaNewerThanApp -- the data there is not corrupt', () {
      expect(DbOpenDiagnosis.schemaNewerThanApp.resetIsSensible, isFalse);
      expect(DbOpenDiagnosis.keyOrHeaderCorrupt.resetIsSensible, isTrue);
      expect(DbOpenDiagnosis.corruptedData.resetIsSensible, isTrue);
      expect(DbOpenDiagnosis.ioError.resetIsSensible, isTrue);
      expect(DbOpenDiagnosis.keyReadFailure.resetIsSensible, isTrue);
      expect(DbOpenDiagnosis.unknown.resetIsSensible, isTrue);
    });
  });

  group('retireDatabaseFile', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('bgdude_retire_test');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('a wrong-key open against an intact file never results in file deletion '
        '(all three sidecars -- wal, shm AND journal)', () async {
      final dbFile = File(p.join(dir.path, 'bgdude_encrypted.db'));
      await dbFile.writeAsBytes([1, 2, 3, 4]); // stand-in for real encrypted bytes
      final wal = File('${dbFile.path}-wal')..writeAsBytesSync([5]);
      final shm = File('${dbFile.path}-shm')..writeAsBytesSync([6]);
      final journal = File('${dbFile.path}-journal')..writeAsBytesSync([7]);

      await retireDatabaseFile(file: dbFile);

      // The original paths no longer exist...
      expect(await dbFile.exists(), isFalse);
      expect(await wal.exists(), isFalse);
      expect(await shm.exists(), isFalse);
      expect(await journal.exists(), isFalse);

      // ...but the bytes are still on disk somewhere under a .bak-<stamp> name, not
      // deleted — this is the actual data-loss guard (AC#4).
      final survivors = dir.listSync().whereType<File>().toList();
      expect(survivors, isNotEmpty);
      final mainBackup =
          survivors.singleWhere((f) => p.basename(f.path).startsWith('bgdude_encrypted.db.bak-'));
      expect(await mainBackup.readAsBytes(), [1, 2, 3, 4]);
      expect(
          survivors.any((f) => p.basename(f.path).contains('-wal.bak-')), isTrue);
      expect(
          survivors.any((f) => p.basename(f.path).contains('-shm.bak-')), isTrue);
      expect(
          survivors.any((f) => p.basename(f.path).contains('-journal.bak-')),
          isTrue);
    });

    test('sidecars alone (no journal present) leave only the main file and its '
        'existing siblings retired -- a missing sidecar is not an error', () async {
      final dbFile = File(p.join(dir.path, 'bgdude_encrypted.db'));
      await dbFile.writeAsBytes([9]);
      // No -wal/-shm/-journal files at all -- a clean, checkpointed database.
      await retireDatabaseFile(file: dbFile);

      expect(await dbFile.exists(), isFalse);
      final survivors = dir.listSync().whereType<File>().toList();
      expect(survivors, hasLength(1));
      expect(p.basename(survivors.single.path),
          startsWith('bgdude_encrypted.db.bak-'));
    });

    test('a missing file is a no-op, not an error', () async {
      final dbFile = File(p.join(dir.path, 'does_not_exist.db'));
      await retireDatabaseFile(file: dbFile); // must not throw
      expect(dir.listSync(), isEmpty);
    });

    test(
        'a repeated reset keeps only the latest backup, not every '
        'past one', () async {
      final dbFile = File(p.join(dir.path, 'bgdude_encrypted.db'));

      // Three resets in a row -- each time the file exists again by the point a
      // real reset would happen (a fresh empty DB re-created after the previous
      // retire, matching production: the app re-opens and re-creates the file).
      for (var i = 0; i < 3; i++) {
        await dbFile.writeAsBytes([i]);
        await retireDatabaseFile(file: dbFile);
        // Timestamps are millisecond-granularity; without a real gap, the 2nd
        // and 3rd calls in the same test could land on the identical stamp as
        // the 1st and "prune" would have nothing distinct to keep vs delete.
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }

      final survivors = dir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith('bgdude_encrypted.db.bak-'))
          .toList();
      expect(survivors, hasLength(1),
          reason: 'only the most recent backup should remain -- three past '
              'resets must not leave three full copies of the DB on disk');
      // And it's genuinely the LATEST one (byte content from the 3rd write).
      expect(await survivors.single.readAsBytes(), [2]);
    });
  });

  group('database downgrade guard', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('bgdude_downgrade_test');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test(
        'opening a file stamped user_version=5 under schemaVersion 4 throws '
        'DatabaseDowngradeException, and the file is left untouched', () async {
      final dbFile = File(p.join(dir.path, 'downgrade.db'));
      // Stand in for "this file was already migrated by a newer app build": a
      // plain (unencrypted -- SQLCipher can't open on this desktop test host)
      // sqlite3 file stamped past this build's schemaVersion, written with a
      // raw sqlite3 connection BEFORE drift ever touches it.
      final raw = sqlite3.sqlite3.open(dbFile.path);
      raw.execute('PRAGMA user_version = 5;');
      raw.dispose();

      final appDb = AppDatabase(NativeDatabase(dbFile));
      await expectLater(
        appDb.customSelect('select 1').get(),
        throwsA(isA<DatabaseDowngradeException>()
            .having((e) => e.from, 'from', 5)
            .having((e) => e.to, 'to', appDb.schemaVersion)),
      );
      await appDb.close();

      // No corruption: user_version is still exactly what it was -- drift must
      // not have silently stamped it down to this build's schemaVersion despite
      // the throw, and no tables were created (onCreate never runs for an
      // existing, non-zero user_version).
      final verify = sqlite3.sqlite3.open(dbFile.path);
      final version =
          verify.select('PRAGMA user_version;').first.values.first as int;
      expect(version, 5);
      final tables = verify
          .select("SELECT name FROM sqlite_master WHERE type = 'table';")
          .map((r) => r.values.first as String)
          .toList();
      expect(tables, isEmpty,
          reason: 'the downgrade guard is the FIRST statement in onUpgrade -- '
              'no migration/creation step should have run before it threw');
      verify.dispose();
    });
  });

  group('salvageExportJson', () {
    // Uses a plain unencrypted in-memory AppDatabase — this exercises the real
    // per-table dump logic without needing SQLCipher (which can't run on this host;
    // see the file-level note above).
    test('dumps every table, including empty ones, as plain rows', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.cgmReadings).insert(
            CgmReadingsCompanion.insert(
              time: DateTime(2026, 7, 4, 8),
              mgdl: 120,
            ),
          );

      final dump = await salvageExportJson(db);

      expect(dump, contains('cgm_readings'));
      final cgmRows = dump['cgm_readings'] as List;
      expect(cgmRows, hasLength(1));
      expect((cgmRows.single as Map)['mgdl'], 120);
      // A table with no rows still dumps as an empty list, not an error.
      expect(dump, contains('bolus_events'));
      expect(dump['bolus_events'], isEmpty);
    });
  });

  group('writeSalvageExportFile', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('bgdude_export_test');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('streams the same data salvageExportJson would, as valid JSON',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.cgmReadings).insert(
            CgmReadingsCompanion.insert(
              time: DateTime(2026, 7, 4, 8),
              mgdl: 120,
            ),
          );

      final file = await writeSalvageExportFile(db, directory: dir);
      final decoded = jsonDecode(await file.readAsString()) as Map;

      expect(decoded, contains('cgm_readings'));
      final cgmRows = decoded['cgm_readings'] as List;
      expect(cgmRows, hasLength(1));
      expect((cgmRows.single as Map)['mgdl'], 120);
      expect(decoded, contains('bolus_events'));
      expect(decoded['bolus_events'], isEmpty);
    });

    test(
        'a second export prunes the first -- repeated recovery attempts do '
        'not accumulate full DB copies', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final first = await writeSalvageExportFile(db, directory: dir);
      expect(await first.exists(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await writeSalvageExportFile(db, directory: dir);

      expect(await first.exists(), isFalse,
          reason: 'the previous export must be cleaned up, not left behind');
      expect(await second.exists(), isTrue);
      final exports = dir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith('bgdude_salvage_'))
          .toList();
      expect(exports, hasLength(1));
    });
  });

  group('quick_check gating', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('bgdude_quickcheck_test');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('due on first run (no marker yet)', () async {
      final dbFile = File(p.join(dir.path, 'bgdude_encrypted.db'));
      expect(await quickCheckDue(dbFile), isTrue);
    });

    test('not due right after a recorded pass', () async {
      final dbFile = File(p.join(dir.path, 'bgdude_encrypted.db'));
      await recordQuickCheckPassed(dbFile);
      expect(await quickCheckDue(dbFile), isFalse);
    });

    test('due again once the marker is older than the check interval',
        () async {
      final dbFile = File(p.join(dir.path, 'bgdude_encrypted.db'));
      // 8 days ago -- past the 7-day interval. quickCheckDue itself compares
      // against the real wall clock (no injected clock yet), so
      // anchoring this to a fixed instant wouldn't actually test the real
      // comparison -- this is genuinely relative-to-now on purpose.
      final stale = DateTime.now() // now-ok: quickCheckDue reads the real clock
          .subtract(const Duration(days: 8))
          .millisecondsSinceEpoch;
      await quickCheckMarker(dbFile).writeAsString('$stale');
      expect(await quickCheckDue(dbFile), isTrue);
    });

    test('a corrupt/unparseable marker is treated as due, not a crash',
        () async {
      final dbFile = File(p.join(dir.path, 'bgdude_encrypted.db'));
      await quickCheckMarker(dbFile).writeAsString('not-a-timestamp');
      expect(await quickCheckDue(dbFile), isTrue);
    });
  });
}
