/// The backup screen's presentation and its enable rules (issue #170).
library;

import 'package:bgdude/ui/widgets/backup_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _entries = [
  BackupEntry(name: 'bgdude-1783000000000.bgdude-backup', sizeBytes: 204800),
];

/// Mutable so assertions made AFTER a tap see the tap.
class _Recorded {
  final List<String> restored = [];
  int exports = 0;
}

Future<_Recorded> _pump(
  WidgetTester tester, {
  String passphrase = '',
  List<BackupEntry> backups = const [],
  bool busy = false,
}) async {
  final recorded = _Recorded();
  final controller = TextEditingController(text: passphrase);
  addTearDown(controller.dispose);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: BackupView(
        passphraseController: controller,
        backups: backups,
        busy: busy,
        onExport: () => recorded.exports++,
        onRestore: (e) => recorded.restored.add(e.name),
      ),
    ),
  ));
  // pump(), not pumpAndSettle(): the busy spinner animates forever and would never
  // settle.
  await tester.pump();
  return recorded;
}

void main() {
  testWidgets('warns up front that a lost passphrase is unrecoverable',
      (tester) async {
    // Discovering this after the fact is how people lose everything.
    await _pump(tester);

    expect(find.textContaining('unreadable — by anyone, including you'),
        findsOneWidget);
  });

  testWidgets('export is disabled without a passphrase', (tester) async {
    await _pump(tester);

    final button = tester.widget<FilledButton>(
        find.byKey(const Key('backup-export')));
    expect(button.onPressed, isNull);
  });

  testWidgets('export is enabled once a passphrase is entered', (tester) async {
    await _pump(tester, passphrase: 'hunter2');

    final button = tester.widget<FilledButton>(
        find.byKey(const Key('backup-export')));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('whitespace is not a passphrase', (tester) async {
    await _pump(tester, passphrase: '   ');

    final button = tester.widget<FilledButton>(
        find.byKey(const Key('backup-export')));
    expect(button.onPressed, isNull);
  });

  testWidgets('nothing is actionable while an operation is in flight',
      (tester) async {
    // A second restore starting mid-restore would be a genuinely bad day.
    await _pump(tester,
        passphrase: 'hunter2', backups: _entries, busy: true);

    final button = tester.widget<FilledButton>(
        find.byKey(const Key('backup-export')));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an empty list says so rather than showing nothing',
      (tester) async {
    await _pump(tester);

    expect(find.text('None yet.'), findsOneWidget);
  });

  testWidgets('a backup lists its name and size', (tester) async {
    await _pump(tester, passphrase: 'p', backups: _entries);

    expect(find.text(_entries.single.name), findsOneWidget);
    expect(find.text('200 KB'), findsOneWidget);
  });

  testWidgets('restore reports which backup was chosen', (tester) async {
    final result =
        await _pump(tester, passphrase: 'p', backups: _entries);

    await tester.tap(find.text('Restore'));
    await tester.pump();

    expect(result.restored, [_entries.single.name]);
  });

  testWidgets('tapping export reports it', (tester) async {
    final result = await _pump(tester, passphrase: 'p');

    await tester.tap(find.byKey(const Key('backup-export')));
    await tester.pump();

    expect(result.exports, 1);
  });
}
