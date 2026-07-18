/// Export/restore sequencing (issue #170) — the part where a mistake costs data.
library;

import 'package:bgdude/data/backup_archive.dart';
import 'package:bgdude/data/backup_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeIo implements BackupIo {
  _FakeIo({this.manifest, this.exportThrows = false});

  BackupManifest? manifest;
  final bool exportThrows;
  int exports = 0;
  int imports = 0;
  String? lastPath;

  @override
  Future<void> exportTo(String path, String passphrase, BackupManifest m) async {
    if (exportThrows) throw Exception('disk full');
    exports++;
    lastPath = path;
  }

  @override
  Future<BackupManifest?> readManifest(String path, String passphrase) async =>
      manifest;

  @override
  Future<void> importFrom(String path, String passphrase) async => imports++;
}

BackupManifest _m({int schema = 4}) => BackupManifest(
      formatVersion: BackupManifest.currentFormatVersion,
      schemaVersion: schema,
      createdAtEpochMs: 1000,
    );

BackupController _controller(_FakeIo io, {bool ready = true}) =>
    BackupController(
      service: ready ? BackupService(io: io, currentSchemaVersion: 4) : null,
      directoryPath: () async => '/docs',
      now: () => DateTime.fromMillisecondsSinceEpoch(1783000000000),
    );

void main() {
  test('export writes a time-ordered filename and reports the path', () async {
    final io = _FakeIo();

    final result = await _controller(io).export('hunter2');

    expect(result.outcome, BackupOutcome.exported);
    expect(result.path, '/docs/bgdude-1783000000000.bgdude-backup');
    expect(io.exports, 1);
    // Zero-padded, so a plain lexicographic sort is chronological even for values
    // with different digit counts — the listing relies on that ordering.
    expect(BackupController.fileNameFor(DateTime.fromMillisecondsSinceEpoch(2))
        .compareTo(BackupController.fileNameFor(
            DateTime.fromMillisecondsSinceEpoch(10))),
        lessThan(0));
  });

  test('no passphrase exports nothing', () async {
    final io = _FakeIo();

    for (final p in ['', '   ']) {
      final result = await _controller(io).export(p);
      expect(result.outcome, BackupOutcome.notReady, reason: '"$p"');
    }
    expect(io.exports, 0);
  });

  test('with no database open, nothing is attempted', () async {
    final io = _FakeIo();

    final result = await _controller(io, ready: false).export('p');

    expect(result.outcome, BackupOutcome.notReady);
    expect(io.exports, 0);
  });

  test('a failed export never reports success', () async {
    final result = await _controller(_FakeIo(exportThrows: true)).export('p');

    expect(result.outcome, BackupOutcome.failed);
    expect(result.message, isNot(contains('Backup written')));
  });

  test('inspect refuses a mismatched archive without importing', () async {
    final io = _FakeIo(manifest: _m(schema: 5));

    final result = await _controller(io).inspect('/docs/a', 'p');

    expect(result.outcome, BackupOutcome.refused);
    expect(result.refusal, RestoreRefusal.fromNewerSchema);
    expect(io.imports, 0, reason: 'inspection must never modify anything');
    // The message must say what to do, not just that it failed.
    expect(result.message, contains('Update the app'));
  });

  test('inspect allows a matching archive, still without importing', () async {
    final io = _FakeIo(manifest: _m());

    final result = await _controller(io).inspect('/docs/a', 'p');

    expect(result.outcome, BackupOutcome.restored);
    expect(io.imports, 0);
  });

  test('an unreadable archive is refused with passphrase advice', () async {
    // Null manifest = wrong passphrase or not a bgdude file; indistinguishable.
    final result = await _controller(_FakeIo()).inspect('/docs/a', 'p');

    expect(result.refusal, RestoreRefusal.unreadable);
    expect(result.message, contains('passphrase'));
  });

  test('restore imports only when the archive is acceptable', () async {
    final ok = _FakeIo(manifest: _m());
    expect((await _controller(ok).restore('/docs/a', 'p')).outcome,
        BackupOutcome.restored);
    expect(ok.imports, 1);

    final bad = _FakeIo(manifest: _m(schema: 3));
    final result = await _controller(bad).restore('/docs/a', 'p');
    expect(result.outcome, BackupOutcome.refused);
    expect(result.refusal, RestoreRefusal.fromOlderSchema);
    expect(bad.imports, 0);
  });

  test('every outcome produces a non-empty message', () async {
    for (final outcome in BackupOutcome.values) {
      final result = outcome == BackupOutcome.refused
          ? const BackupResult(BackupOutcome.refused,
              refusal: RestoreRefusal.unreadable)
          : BackupResult(outcome, error: 'x');
      expect(result.message, isNotEmpty, reason: outcome.name);
    }
  });
}
