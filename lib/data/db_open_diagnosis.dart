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

import 'package:flutter/foundation.dart';
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
  unknown,

  /// `SecureKeyStore.open()` couldn't read the passphrase from secure storage, but a
  /// plain marker confirms one was generated before (TASK-249) — this looks like a
  /// transient Keystore failure (OS update, device restore, biometric change), not
  /// file corruption. The encrypted DB file itself was never even touched.
  keyReadFailure,

  /// The on-disk schema is NEWER than this build understands (TASK-199) — this
  /// build is older than the data (e.g. a sideload rollback after a newer version
  /// already migrated the file). The data is not corrupt; it needs a newer app
  /// build, not a reset.
  schemaNewerThanApp;

  /// Whether any of the app's own data might still be readable via SQL — true only
  /// for [corruptedData], where the key/header were already confirmed fine and some
  /// tables may still be intact even though quick_check found damage elsewhere.
  bool get salvageable => this == DbOpenDiagnosis.corruptedData;

  /// Whether the destructive "reset storage" recovery action makes sense to offer
  /// at all (TASK-199). False only for [schemaNewerThanApp]: the file isn't
  /// corrupt, so resetting would destroy genuinely intact, newer data for no
  /// reason — the actual fix is installing a newer app build, not a reset.
  bool get resetIsSensible => this != DbOpenDiagnosis.schemaNewerThanApp;
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
  if (error is DatabaseDowngradeException) return DbOpenDiagnosis.schemaNewerThanApp;
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

/// TASK-254: `PRAGMA quick_check` is a page-by-page scan and every page is
/// SQLCipher-decrypted -- for a tool that accumulates years of CGM data (~288
/// rows/day) that's a real, growing launch cost, and it ran on EVERY cold start
/// (including the healthy path) even though the cheap `select 1` read just above it
/// already catches the key/header failure modes the recovery flow most needs. Gate
/// the deeper scan to once every [_quickCheckInterval] instead.
const _quickCheckInterval = Duration(days: 7);

/// A plain sentinel file (not DB-backed -- this runs before `KvStore.init`, and it
/// must survive independently of whether the DB itself is healthy) recording when
/// `quick_check` last completed cleanly. Missing (first run, or the DB file itself
/// is new/was reset) or stale means "due"; a corrupted result never updates it, so a
/// known-bad DB keeps being re-checked every launch until it's fixed, not just once
/// every [_quickCheckInterval]. Not private (unlike the app's usual convention) so
/// the pure file-based gating logic is directly testable without needing a real
/// SQLCipher-backed database, which this test host can't run.
@visibleForTesting
File quickCheckMarker(File dbFile) => File('${dbFile.path}.quick_check_at');

@visibleForTesting
Future<bool> quickCheckDue(File dbFile) async {
  final marker = quickCheckMarker(dbFile);
  if (!await marker.exists()) return true;
  final lastMs = int.tryParse((await marker.readAsString()).trim());
  if (lastMs == null) return true;
  final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
  return DateTime.now().difference(last) > _quickCheckInterval;
}

@visibleForTesting
Future<void> recordQuickCheckPassed(File dbFile) async {
  try {
    await quickCheckMarker(dbFile)
        .writeAsString(DateTime.now().millisecondsSinceEpoch.toString());
  } catch (_) {
    // Best-effort -- a failed write just means quick_check runs again next launch,
    // which is the safe direction to fail in.
  }
}

/// Opens the encrypted database at [passphrase], running a first real read (proves the
/// key) and then, when due (TASK-254), `PRAGMA quick_check` (proves deeper integrity)
/// before handing back a ready-to-use repository. On any failure, classifies why via
/// [classifyDbOpenFailure] and returns an in-memory fallback so the app still runs.
/// [file] overrides the on-disk location for tests.
Future<DbOpenResult> openHistoryRepository(String passphrase, {File? file}) async {
  final dbFile = file ?? await defaultDatabaseFile();
  AppDatabase? db;
  try {
    db = AppDatabase(openEncryptedDatabase(passphrase, file: file));
    await db.customSelect('select 1').get(); // first real read — proves the key
    if (!await quickCheckDue(dbFile)) {
      return DbOpenResult(repository: DriftHistoryRepository(db), db: db);
    }
    try {
      final rows = await db.customSelect('PRAGMA quick_check').get();
      final ok = rows.isNotEmpty &&
          rows.first.data.values.first.toString().toLowerCase() == 'ok';
      if (ok) {
        await recordQuickCheckPassed(dbFile);
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

/// Writes a table-by-table dump (the same shape [salvageExportJson] returns) to a
/// file under [directory] and returns its path, ready to hand to the share sheet.
///
/// TASK-254: streams each table's rows directly to disk instead of building the
/// same data as an in-memory Map (via [salvageExportJson]) and then encoding the
/// WHOLE multi-table result as one big string -- for years of CGM history that
/// held the entire dump in memory twice over. Peak memory here is bounded to one
/// table's row list at a time, not the sum of every table plus its encoded copy.
/// Also prunes any previous `bgdude_salvage_*.json` export left in [directory] --
/// each recovery attempt otherwise leaves another full copy behind indefinitely.
Future<File> writeSalvageExportFile(AppDatabase db,
    {required Directory directory}) async {
  await _pruneOldSalvageExports(directory);
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${directory.path}/bgdude_salvage_$stamp.json');
  final sink = file.openWrite();
  try {
    sink.write('{\n');
    var firstTable = true;
    for (final table in db.allTables) {
      final name = table.actualTableName;
      sink.write(firstTable ? '  ' : ',\n  ');
      firstTable = false;
      sink.write('${jsonEncode(name)}: ');
      try {
        final rows = await db.customSelect('SELECT * FROM $name').get();
        sink.write('[');
        for (var i = 0; i < rows.length; i++) {
          if (i > 0) sink.write(',');
          sink.write(jsonEncode(rows[i].data));
        }
        sink.write(']');
      } catch (e) {
        sink.write(jsonEncode({'error': e.toString()}));
      }
    }
    sink.write('\n}\n');
  } finally {
    await sink.close();
  }
  return file;
}

/// Deletes any `bgdude_salvage_*.json` files already in [directory] -- best-effort,
/// a locked/already-gone file must not block a fresh export from being written.
Future<void> _pruneOldSalvageExports(Directory directory) async {
  if (!await directory.exists()) return;
  await for (final entry in directory.list()) {
    if (entry is! File) continue;
    final name = entry.uri.pathSegments.last;
    if (!name.startsWith('bgdude_salvage_') || !name.endsWith('.json')) continue;
    try {
      await entry.delete();
    } catch (_) {}
  }
}
