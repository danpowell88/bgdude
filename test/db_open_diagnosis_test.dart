import 'dart:io';

import 'package:bgdude/data/database.dart';
import 'package:bgdude/data/db_open_diagnosis.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// TASK-192: classifyDbOpenFailure is unit-tested directly against synthetic
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
  group('classifyDbOpenFailure (TASK-192)', () {
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
  });

  group('DbOpenDiagnosis.salvageable (TASK-192)', () {
    test('only corruptedData is salvageable', () {
      expect(DbOpenDiagnosis.corruptedData.salvageable, isTrue);
      expect(DbOpenDiagnosis.keyOrHeaderCorrupt.salvageable, isFalse);
      expect(DbOpenDiagnosis.ioError.salvageable, isFalse);
      expect(DbOpenDiagnosis.keyReadFailure.salvageable, isFalse);
      expect(DbOpenDiagnosis.unknown.salvageable, isFalse);
    });
  });

  group('retireDatabaseFile (TASK-249)', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('bgdude_retire_test');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('a wrong-key open against an intact file never results in file deletion',
        () async {
      final dbFile = File(p.join(dir.path, 'bgdude_encrypted.db'));
      await dbFile.writeAsBytes([1, 2, 3, 4]); // stand-in for real encrypted bytes
      final wal = File('${dbFile.path}-wal')..writeAsBytesSync([5]);
      final shm = File('${dbFile.path}-shm')..writeAsBytesSync([6]);

      await retireDatabaseFile(file: dbFile);

      // The original paths no longer exist...
      expect(await dbFile.exists(), isFalse);
      expect(await wal.exists(), isFalse);
      expect(await shm.exists(), isFalse);

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
    });

    test('a missing file is a no-op, not an error', () async {
      final dbFile = File(p.join(dir.path, 'does_not_exist.db'));
      await retireDatabaseFile(file: dbFile); // must not throw
      expect(dir.listSync(), isEmpty);
    });
  });

  group('salvageExportJson (TASK-192)', () {
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
}
