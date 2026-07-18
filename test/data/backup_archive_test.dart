/// Encrypted backup: manifest handling and the restore decision (issue #170).
///
/// The cipher work itself needs a real SQLCipher runtime and cannot run on this host.
/// What IS tested here is the part that decides whether someone's live health data gets
/// overwritten — which is the part where being wrong actually costs something.
library;

import 'package:bgdude/data/backup_archive.dart';
import 'package:bgdude/data/backup_io_sqlcipher.dart' show escapeSqlLiteral;
import 'package:flutter_test/flutter_test.dart';

BackupManifest _manifest({int format = 1, int schema = 4, int created = 1000}) =>
    BackupManifest(
      formatVersion: format,
      schemaVersion: schema,
      createdAtEpochMs: created,
    );

/// Records what it was asked to do; performs no cipher work.
class _FakeIo implements BackupIo {
  _FakeIo({this.manifest, this.readThrows = false});

  BackupManifest? manifest;
  final bool readThrows;

  int exports = 0;
  int imports = 0;
  String? lastPath;
  String? lastPassphrase;
  BackupManifest? lastManifest;

  @override
  Future<void> exportTo(
      String path, String passphrase, BackupManifest m) async {
    exports++;
    lastPath = path;
    lastPassphrase = passphrase;
    lastManifest = m;
  }

  @override
  Future<BackupManifest?> readManifest(String path, String passphrase) async {
    if (readThrows) throw Exception('cannot open');
    return manifest;
  }

  @override
  Future<void> importFrom(String path, String passphrase) async {
    imports++;
  }
}

void main() {
  group('BackupManifest', () {
    test('round-trips through JSON', () {
      const original = BackupManifest(
        formatVersion: 1,
        schemaVersion: 4,
        createdAtEpochMs: 1783000000000,
        appVersion: '0.1.0',
      );

      final decoded = BackupManifest.decode(original.encode())!;

      expect(decoded.formatVersion, 1);
      expect(decoded.schemaVersion, 4);
      expect(decoded.createdAtEpochMs, 1783000000000);
      expect(decoded.appVersion, '0.1.0');
    });

    test('unreadable input decodes to null rather than throwing', () {
      // A corrupt or foreign file must produce a clear refusal, not a crash partway
      // through a restore.
      for (final bad in [
        null,
        '',
        '   ',
        'not json',
        '[]',
        '{}',
        '{"formatVersion":"1","schemaVersion":4,"createdAtEpochMs":1}',
        '{"formatVersion":1,"schemaVersion":null,"createdAtEpochMs":1}',
      ]) {
        expect(BackupManifest.decode(bad), isNull, reason: '$bad');
      }
    });
  });

  group('checkRestore', () {
    test('a matching schema is allowed', () {
      expect(checkRestore(_manifest(schema: 4), currentSchemaVersion: 4).allowed,
          isTrue);
    });

    test('a NEWER archive is refused', () {
      // It would replace working data with something this build cannot read.
      final v = checkRestore(_manifest(schema: 5), currentSchemaVersion: 4);
      expect(v.allowed, isFalse);
      expect(v.refusal, RestoreRefusal.fromNewerSchema);
    });

    test('an OLDER archive is refused too', () {
      // The subtler hazard: it would open, look fine, and be migrated in place —
      // turning the backup the user was keeping as a fallback into a one-way upgrade.
      final v = checkRestore(_manifest(schema: 3), currentSchemaVersion: 4);
      expect(v.allowed, isFalse);
      expect(v.refusal, RestoreRefusal.fromOlderSchema);
    });

    test('an unreadable archive is refused', () {
      final v = checkRestore(null, currentSchemaVersion: 4);
      expect(v.refusal, RestoreRefusal.unreadable);
    });

    test('an unknown archive format is refused', () {
      final v = checkRestore(_manifest(format: 99), currentSchemaVersion: 4);
      expect(v.refusal, RestoreRefusal.unknownFormat);
    });

    test('every refusal explains what to do next', () {
      // "Restore failed" on the only copy of someone's health history is not an
      // acceptable place to stop.
      for (final r in RestoreRefusal.values) {
        final message = restoreRefusalMessage(r);
        expect(message, isNotEmpty, reason: r.name);
        expect(message.length, greaterThan(40), reason: r.name);
      }
      // The wrong-passphrase case must say so — it is by far the likeliest cause and
      // is indistinguishable from a damaged file.
      expect(restoreRefusalMessage(RestoreRefusal.unreadable),
          contains('passphrase'));
    });
  });

  group('BackupService', () {
    test('export stamps the current schema version into the manifest', () async {
      final io = _FakeIo();
      final service = BackupService(io: io, currentSchemaVersion: 4);

      final manifest = await service.export(
        path: '/tmp/b.db',
        passphrase: 'hunter2',
        now: DateTime.fromMillisecondsSinceEpoch(1783000000000),
        appVersion: '0.1.0',
      );

      expect(io.exports, 1);
      expect(io.lastPassphrase, 'hunter2');
      expect(manifest.schemaVersion, 4);
      expect(manifest.formatVersion, BackupManifest.currentFormatVersion);
      expect(manifest.createdAtEpochMs, 1783000000000);
    });

    test('inspect does not import anything', () async {
      // The confirmation screen must be able to look before anything is destroyed.
      final io = _FakeIo(manifest: _manifest());
      final service = BackupService(io: io, currentSchemaVersion: 4);

      final verdict = await service.inspect(path: '/tmp/b.db', passphrase: 'p');

      expect(verdict.allowed, isTrue);
      expect(io.imports, 0);
    });

    test('a failure to open reads as unreadable, not as a crash', () async {
      final service =
          BackupService(io: _FakeIo(readThrows: true), currentSchemaVersion: 4);

      final verdict = await service.inspect(path: '/tmp/b.db', passphrase: 'p');

      expect(verdict.refusal, RestoreRefusal.unreadable);
    });

    test('restore re-checks instead of trusting the caller', () async {
      // This is the one operation that destroys data; a UI that forgot to call
      // inspect() must not be able to trigger it anyway.
      final io = _FakeIo(manifest: _manifest(schema: 5));
      final service = BackupService(io: io, currentSchemaVersion: 4);

      final verdict = await service.restore(path: '/tmp/b.db', passphrase: 'p');

      expect(verdict.allowed, isFalse);
      expect(io.imports, 0, reason: 'nothing may be overwritten on a refusal');
    });

    test('an allowed restore does import', () async {
      final io = _FakeIo(manifest: _manifest(schema: 4));
      final service = BackupService(io: io, currentSchemaVersion: 4);

      final verdict = await service.restore(path: '/tmp/b.db', passphrase: 'p');

      expect(verdict.allowed, isTrue);
      expect(io.imports, 1);
    });
  });

  group('escapeSqlLiteral', () {
    test("doubles apostrophes so a passphrase isn't silently altered", () {
      // Passphrases contain apostrophes. Interpolating one unescaped would not just
      // fail — it would key the archive with a DIFFERENT string than the user typed,
      // producing a backup nobody can ever open.
      expect(escapeSqlLiteral("it's fine"), "it''s fine");
      expect(escapeSqlLiteral("''"), "''''");
      expect(escapeSqlLiteral('plain'), 'plain');
      expect(escapeSqlLiteral(''), '');
    });
  });
}
