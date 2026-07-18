/// The SQLCipher half of backup/restore (issue #170).
///
/// Uses SQLCipher's own `sqlcipher_export()` to write the whole live database into a new
/// file keyed by the user's passphrase, and the same mechanism in reverse to restore.
/// No second cipher library, and no hand-rolled archive format.
///
/// Kept apart from `backup_archive.dart` because none of this can run on a desktop test
/// host — SQLCipher needs the native library. The decisions worth testing (what may be
/// restored, and what to tell the user when it may not) live in that file instead.
library;

import 'dart:io';

import 'backup_archive.dart';
import 'database.dart';

/// SQL-escapes a passphrase for use in a PRAGMA/KEY literal.
///
/// Passphrases are user-chosen and will contain apostrophes. Interpolating one unescaped
/// would not just fail — it would produce a *different key* than the user typed, and an
/// archive that can never be opened again.
String escapeSqlLiteral(String value) => value.replaceAll("'", "''");

/// The SQL these operations issue, built as pure strings.
///
/// Worth having separately from the IO: this is where a passphrase or path with an
/// apostrophe would break out of its literal, and where getting the escaping wrong keys
/// an archive with a different string than the user typed — producing a backup nobody can
/// ever open. Testable without a database.
class BackupSql {
  const BackupSql._();

  /// ATTACH a SQLCipher database at [path] as [alias], keyed with [passphrase].
  static String attach(String alias, String path, String passphrase) =>
      "ATTACH DATABASE '${escapeSqlLiteral(path)}' AS $alias "
      "KEY '${escapeSqlLiteral(passphrase)}'";

  static String detach(String alias) => 'DETACH DATABASE $alias';

  /// Copy the live database into [alias], encrypted under the attached key.
  static String exportInto(String alias) => "SELECT sqlcipher_export('$alias')";

  /// Copy [alias] into the live database, re-encrypted under the live key.
  static String importFrom(String alias) =>
      "SELECT sqlcipher_export('main', '$alias')";

  static String createMeta(String alias, String table) =>
      'CREATE TABLE $alias.$table (manifest TEXT NOT NULL)';

  static String insertMeta(String alias, String table, String manifest) =>
      'INSERT INTO $alias.$table (manifest) VALUES '
      "('${escapeSqlLiteral(manifest)}')";

  static String selectMeta(String alias, String table) =>
      'SELECT manifest FROM $alias.$table';
}

class SqlCipherBackupIo implements BackupIo {
  const SqlCipherBackupIo(this._db);

  final AppDatabase _db;

  static const String _metaTable = 'backup_meta';

  @override
  Future<void> exportTo(
      String path, String passphrase, BackupManifest manifest) async {
    // A leftover file would be exported INTO rather than replaced, mixing two backups.
    final file = File(path);
    if (await file.exists()) await file.delete();

    await _db.customStatement(BackupSql.attach('backup', path, passphrase));
    try {
      await _db.customStatement(BackupSql.exportInto('backup'));
      // Written after the export: sqlcipher_export copies the live schema, so creating
      // the table first would see it dropped again.
      await _db.customStatement(BackupSql.createMeta('backup', _metaTable));
      await _db.customStatement(
          BackupSql.insertMeta('backup', _metaTable, manifest.encode()));
    } finally {
      await _db.customStatement(BackupSql.detach('backup'));
    }
  }

  @override
  Future<BackupManifest?> readManifest(String path, String passphrase) async {
    if (!await File(path).exists()) return null;
    try {
      await _db.customStatement(BackupSql.attach('restore', path, passphrase));
    } catch (_) {
      // Wrong passphrase, or not a SQLCipher file at all.
      return null;
    }
    try {
      final rows = await _db
          .customSelect(BackupSql.selectMeta('restore', _metaTable))
          .get();
      if (rows.isEmpty) return null;
      return BackupManifest.decode(rows.first.read<String>('manifest'));
    } catch (_) {
      // Opened, but has no manifest — someone else's SQLCipher database.
      return null;
    } finally {
      await _db.customStatement(BackupSql.detach('restore'));
    }
  }

  @override
  Future<void> importFrom(String path, String passphrase) async {
    // NOT a file copy. The archive is keyed with the user's passphrase while the live
    // database is keyed from the platform keystore, so copying the archive into place
    // would leave a file the app itself can no longer open — a restore that destroys
    // access to the data it just restored.
    //
    // `sqlcipher_export(target, source)` copies between two attached databases and
    // re-encrypts under the target's key, which is exactly the re-key needed here.
    await _db.customStatement(BackupSql.attach('restore', path, passphrase));
    try {
      // Safety net first: the live data goes to a timestamped archive under the SAME
      // passphrase, so a restore the user regrets is undoable with a passphrase they
      // already have. This is the one operation in the app that destroys data; it must
      // not be the one without a fallback.
      await _writeSafetyCopy(passphrase);

      // main <- restore, re-encrypted under main's key.
      await _db.customStatement(BackupSql.importFrom('restore'));
    } finally {
      await _db.customStatement(BackupSql.detach('restore'));
    }
  }

  /// Exports the CURRENT database beside the live one before it is overwritten.
  Future<void> _writeSafetyCopy(String passphrase) async {
    final live = await defaultDatabaseFile();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${live.path}.pre-restore-$stamp';
    await exportTo(
      path,
      passphrase,
      BackupManifest(
        formatVersion: BackupManifest.currentFormatVersion,
        schemaVersion: _db.schemaVersion,
        createdAtEpochMs: stamp,
      ),
    );
  }
}
