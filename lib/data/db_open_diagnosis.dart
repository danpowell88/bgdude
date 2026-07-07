/// Classifies why the encrypted database failed to open (TASK-192), so the recovery
/// flow can offer the right next step instead of one generic "storage failed" message.
///
/// SQLCipher can't always tell a wrong passphrase apart from file corruption: both
/// produce SQLITE_NOTADB when the very first read after `PRAGMA key` fails (a
/// documented SQLCipher limitation, not a shortcut taken here) — reported honestly as
/// [DbOpenDiagnosis.keyOrHeaderCorrupt] rather than falsely picking one. A failure that
/// happens LATER — the key was fine (reads already succeeded) but `PRAGMA quick_check`
/// then finds damage — is reported with more confidence as
/// [DbOpenDiagnosis.corruptedData].
library;

import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'database.dart';
import 'history_repository.dart';

enum DbOpenDiagnosis {
  /// The very first read failed. Could be a wrong passphrase (e.g. Keystore
  /// invalidation, or a backup restored under a different key) OR the file being
  /// corrupt/not a database at all — SQLCipher can't distinguish these at the SQL
  /// level, so this category is deliberately combined rather than guessed at.
  keyOrHeaderCorrupt,

  /// The key was confirmed correct (a read already succeeded), but a deeper integrity
  /// check found damage. Higher-confidence "this file is actually corrupt".
  corruptedData,

  /// A filesystem/OS-level problem (permissions, disk full, can't open the path) —
  /// nothing to do with the key or the data; a plain retry may just work.
  ioError,

  /// Didn't match a recognised pattern.
  unknown;

  /// Whether any of the app's own data might still be readable via SQL — true only
  /// for [corruptedData], where the key/header were already confirmed fine and some
  /// tables may still be intact even though quick_check found damage elsewhere.
  bool get salvageable => this == DbOpenDiagnosis.corruptedData;
}

/// SQLite result codes relevant here (sqlite.org/rescode.html).
const _sqliteCorrupt = 11;
const _sqliteCantOpen = 14;
const _sqliteIoErr = 10;
const _sqliteFull = 13;
const _sqlitePerm = 3;
const _sqliteNotADb = 26;

/// Classifies the error thrown while opening the encrypted database. [keyConfirmed]
/// is true only when a read against the newly-keyed connection had already succeeded
/// before this error occurred (i.e. this error came from a later, deeper check like
/// `PRAGMA quick_check`, not the very first post-key query).
DbOpenDiagnosis classifyDbOpenFailure(Object error, {required bool keyConfirmed}) {
  if (error is FileSystemException) return DbOpenDiagnosis.ioError;
  if (error is SqliteException) {
    final code = error.resultCode;
    if (code == _sqliteCantOpen ||
        code == _sqliteIoErr ||
        code == _sqliteFull ||
        code == _sqlitePerm) {
      return DbOpenDiagnosis.ioError;
    }
    if (code == _sqliteNotADb) {
      return keyConfirmed
          ? DbOpenDiagnosis.corruptedData
          : DbOpenDiagnosis.keyOrHeaderCorrupt;
    }
    if (code == _sqliteCorrupt) return DbOpenDiagnosis.corruptedData;
  }
  return DbOpenDiagnosis.unknown;
}

/// The outcome of attempting to open the encrypted store at startup.
class DbOpenResult {
  const DbOpenResult({required this.repository, this.diagnosis, this.db});

  /// Ready to use either way: [DriftHistoryRepository] on success, or an in-memory
  /// fallback so the app still runs (read-only session, nothing persists) on failure.
  final HistoryRepository repository;

  /// Null on success. Set on failure so the recovery screen can explain what
  /// happened and offer the right next step (retry / salvage export / reset).
  final DbOpenDiagnosis? diagnosis;

  /// The open, keyed connection — set whenever the key was confirmed correct: on a
  /// clean open (same object [repository] wraps; callers that need the raw
  /// [AppDatabase], e.g. `KvStore.init`, read it from here) and on
  /// [DbOpenDiagnosis.corruptedData] (kept open so a salvage export can try reading
  /// whatever tables are still intact). Null when the key/header itself didn't check
  /// out — nothing more can be read at that point.
  final AppDatabase? db;
}

/// Opens the encrypted database at [passphrase], running a first real read (proves the
/// key) and then `PRAGMA quick_check` (proves deeper integrity) before handing back a
/// ready-to-use repository. On any failure, classifies why via [classifyDbOpenFailure]
/// and returns an in-memory fallback so the app still runs. [file] overrides the on-disk
/// location for tests.
Future<DbOpenResult> openHistoryRepository(String passphrase, {File? file}) async {
  AppDatabase? db;
  try {
    db = AppDatabase(openEncryptedDatabase(passphrase, file: file));
    await db.customSelect('select 1').get(); // first real read — proves the key
    try {
      final rows = await db.customSelect('PRAGMA quick_check').get();
      final ok = rows.isNotEmpty &&
          rows.first.data.values.first.toString().toLowerCase() == 'ok';
      if (ok) {
        return DbOpenResult(repository: DriftHistoryRepository(db), db: db);
      }
      return DbOpenResult(
        repository: InMemoryHistoryRepository(),
        diagnosis: DbOpenDiagnosis.corruptedData,
        db: db,
      );
    } catch (e) {
      return DbOpenResult(
        repository: InMemoryHistoryRepository(),
        diagnosis: classifyDbOpenFailure(e, keyConfirmed: true),
        db: db,
      );
    }
  } catch (e) {
    try {
      await db?.close();
    } catch (_) {}
    return DbOpenResult(
      repository: InMemoryHistoryRepository(),
      diagnosis: classifyDbOpenFailure(e, keyConfirmed: false),
    );
  }
}

/// TASK-192 "salvage export": a best-effort raw JSON dump of every table still
/// readable on a [db] that failed [PRAGMA quick_check] — some tables may be intact
/// even when others aren't. Not the full encrypted-backup format (TASK-156); this is
/// specifically for pulling *something* out of a database the recovery screen is
/// about to let the user delete. Returns `{tableName: {rows: N, error: '...'}}` for
/// tables that couldn't be read, alongside the successfully-dumped ones, so the user
/// (or a support conversation) can see exactly what didn't make it.
Future<Map<String, dynamic>> salvageExportJson(AppDatabase db) async {
  final out = <String, dynamic>{};
  for (final table in db.allTables) {
    final name = table.actualTableName;
    try {
      final rows = await db.customSelect('SELECT * FROM $name').get();
      out[name] = [for (final r in rows) r.data];
    } catch (e) {
      out[name] = {'error': e.toString()};
    }
  }
  return out;
}

/// Writes [salvageExportJson]'s result to a file under [directory] and returns its
/// path, ready to hand to the share sheet.
Future<File> writeSalvageExportFile(AppDatabase db,
    {required Directory directory}) async {
  final data = await salvageExportJson(db);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${directory.path}/bgdude_salvage_$stamp.json');
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  return file;
}
