/// The SQL backup/restore issues (issue #170).
///
/// This is where a passphrase or path containing an apostrophe would break out of its
/// literal — and worse, where wrong escaping keys an archive with a DIFFERENT string
/// than the user typed, producing a backup nobody can ever open.
library;

import 'package:bgdude/data/backup_io_sqlcipher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attach escapes both the path and the passphrase', () {
    final sql = BackupSql.attach("backup", "/it's/a path.db", "pa'ss");

    expect(sql, contains("'/it''s/a path.db'"));
    expect(sql, contains("KEY 'pa''ss'"));
    expect(sql, startsWith('ATTACH DATABASE '));
  });

  test('a passphrase of only quotes survives escaping', () {
    final sql = BackupSql.attach('backup', '/b.db', "''");
    expect(sql, contains("KEY ''''''"));
  });

  test('export copies the live database INTO the archive', () {
    expect(BackupSql.exportInto('backup'), "SELECT sqlcipher_export('backup')");
  });

  test('import copies the archive INTO the live database', () {
    // Direction matters enormously: the two-argument form re-encrypts under main's
    // key. Getting it backwards would overwrite the user's backup with their live
    // data — destroying the thing they were restoring from.
    expect(BackupSql.importFrom('restore'),
        "SELECT sqlcipher_export('main', 'restore')");
  });

  test('import and export are not the same statement', () {
    expect(BackupSql.exportInto('restore'),
        isNot(BackupSql.importFrom('restore')));
  });

  test('the manifest insert escapes the JSON payload', () {
    // The manifest is JSON and contains quotes; an unescaped insert would be a
    // syntax error at best.
    final sql = BackupSql.insertMeta(
        'backup', 'backup_meta', '{"appVersion":"it\'s 1.0"}');

    expect(sql, contains("it''s 1.0"));
    expect(sql, startsWith('INSERT INTO backup.backup_meta'));
  });

  test('meta statements name the aliased schema, not the live one', () {
    // Writing the manifest into `main` would put a backup_meta table in the user's
    // live database and then export it into every future archive.
    expect(BackupSql.createMeta('backup', 'backup_meta'),
        contains('backup.backup_meta'));
    expect(BackupSql.selectMeta('restore', 'backup_meta'),
        contains('restore.backup_meta'));
  });

  test('detach names the alias', () {
    expect(BackupSql.detach('restore'), 'DETACH DATABASE restore');
  });

  test('escapeSqlLiteral leaves ordinary text alone', () {
    expect(escapeSqlLiteral('plain passphrase'), 'plain passphrase');
    expect(escapeSqlLiteral(''), '');
  });
}
