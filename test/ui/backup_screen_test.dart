/// The backup screen's flow: confirm before overwriting, and never claim success it
/// didn't have (issue #170).
library;

import 'package:bgdude/data/backup_archive.dart';
import 'package:bgdude/data/backup_controller.dart';
import 'package:bgdude/ui/backup_screen.dart';
import 'package:bgdude/ui/widgets/backup_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeIo implements BackupIo {
  _FakeIo({this.manifest});
  BackupManifest? manifest;
  int imports = 0;
  int exports = 0;

  @override
  Future<void> exportTo(String p, String pass, BackupManifest m) async =>
      exports++;
  @override
  Future<BackupManifest?> readManifest(String p, String pass) async => manifest;
  @override
  Future<void> importFrom(String p, String pass) async => imports++;
}

BackupManifest _m({int schema = 4}) => BackupManifest(
      formatVersion: BackupManifest.currentFormatVersion,
      schemaVersion: schema,
      createdAtEpochMs: 1000,
    );

const _entry = BackupEntry(name: 'bgdude-1.bgdude-backup', sizeBytes: 1024);

Future<List<String>> _pump(WidgetTester tester, _FakeIo io,
    {List<BackupEntry> backups = const [_entry]}) async {
  final shared = <String>[];
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: BackupScreen(
        controllerOverride: BackupController(
          service: BackupService(io: io, currentSchemaVersion: 4),
          directoryPath: () async => '/docs',
          now: () => DateTime.fromMillisecondsSinceEpoch(1),
        ),
        listBackups: () async => backups,
        shareFile: (p) async => shared.add(p),
      ),
    ),
  ));
  await tester.pump();
  return shared;
}

Future<void> _enterPassphrase(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('backup-passphrase')), 'hunter2');
  await tester.pump();
}

void main() {
  testWidgets('export writes and shares the archive', (tester) async {
    final io = _FakeIo();
    final shared = await _pump(tester, io);
    await _enterPassphrase(tester);

    await tester.tap(find.byKey(const Key('backup-export')));
    await tester.pump();
    await tester.pump();

    expect(io.exports, 1);
    expect(shared, ['/docs/bgdude-0000000000001.bgdude-backup']);
  });

  testWidgets('a refused restore never reaches the confirmation', (tester) async {
    // Nothing may be overwritten, and the user must not be asked to confirm
    // something that was never going to happen.
    final io = _FakeIo(manifest: _m(schema: 9));
    await _pump(tester, io);
    await _enterPassphrase(tester);

    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Replace all data?'), findsNothing);
    expect(io.imports, 0);
    expect(find.textContaining('newer version'), findsOneWidget);
  });

  testWidgets('an acceptable restore asks first and can be cancelled',
      (tester) async {
    final io = _FakeIo(manifest: _m());
    await _pump(tester, io);
    await _enterPassphrase(tester);

    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Replace all data?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(io.imports, 0, reason: 'cancelling must not overwrite anything');
  });

  testWidgets('confirming performs the restore', (tester) async {
    final io = _FakeIo(manifest: _m());
    await _pump(tester, io);
    await _enterPassphrase(tester);

    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('backup-confirm-restore')));
    await tester.pumpAndSettle();

    expect(io.imports, 1);
    expect(find.textContaining('Restart the app'), findsOneWidget);
  });

  testWidgets('with no backups the list says so', (tester) async {
    await _pump(tester, _FakeIo(), backups: const []);

    expect(find.text('None yet.'), findsOneWidget);
  });
}
