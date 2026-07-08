/// TASK-252: the recovery screen's export-visibility gate and destructive
/// double-confirm dialog had no test coverage at all. openHistoryRepository() itself
/// can't be exercised on this desktop host (it always routes through
/// sqlcipher_flutter_libs' openCipherOnAndroid, which needs a real Android device --
/// see db_open_diagnosis_test.dart's own note), but DbRecoveryScreen reads its inputs
/// via dbOpenDiagnosisProvider/dbOpenSalvageDbProvider, so its own logic -- which is
/// what actually decides whether the export button appears, and what the destructive
/// reset gate requires -- is fully testable by overriding those two providers directly.
library;

import 'package:bgdude/data/database.dart';
import 'package:bgdude/data/db_open_diagnosis.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/db_recovery_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness(List<Override> overrides) => ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: DbRecoveryScreen()),
      );

  group('salvage export visibility (TASK-252 AC#2)', () {
    testWidgets(
        'corruptedData with an open salvage db exposes the export button',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(harness([
        dbOpenDiagnosisProvider.overrideWithValue(DbOpenDiagnosis.corruptedData),
        dbOpenSalvageDbProvider.overrideWithValue(db),
      ]));

      expect(find.text('Export what\'s still readable'), findsOneWidget);
    });

    testWidgets(
        'keyOrHeaderCorrupt (not salvageable) does NOT expose an export path, '
        'even if a db happened to be passed', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(harness([
        dbOpenDiagnosisProvider.overrideWithValue(DbOpenDiagnosis.keyOrHeaderCorrupt),
        dbOpenSalvageDbProvider.overrideWithValue(db), // salvageable gates on BOTH
      ]));

      expect(find.text('Export what\'s still readable'), findsNothing);
    });

    testWidgets(
        'corruptedData with no open db (the real production shape for that '
        'branch\'s failure path) does NOT expose an export path', (tester) async {
      await tester.pumpWidget(harness([
        dbOpenDiagnosisProvider.overrideWithValue(DbOpenDiagnosis.corruptedData),
        dbOpenSalvageDbProvider.overrideWithValue(null),
      ]));

      expect(find.text('Export what\'s still readable'), findsNothing);
    });

    testWidgets('schemaNewerThanApp never offers reset (TASK-199) or export',
        (tester) async {
      await tester.pumpWidget(harness([
        dbOpenDiagnosisProvider.overrideWithValue(DbOpenDiagnosis.schemaNewerThanApp),
        dbOpenSalvageDbProvider.overrideWithValue(null),
      ]));

      expect(find.text('Export what\'s still readable'), findsNothing);
      expect(find.text('Reset storage (destructive)'), findsNothing);
    });
  });

  group('destructive reset requires two confirmations (TASK-252 AC#3)',
      () {
    Future<void> pumpKeyOrHeaderCorrupt(WidgetTester tester) => tester.pumpWidget(
        harness([
          dbOpenDiagnosisProvider.overrideWithValue(DbOpenDiagnosis.keyOrHeaderCorrupt),
          dbOpenSalvageDbProvider.overrideWithValue(null),
        ]));

    testWidgets('tapping reset shows the first confirmation, not an immediate reset',
        (tester) async {
      await pumpKeyOrHeaderCorrupt(tester);

      await tester.tap(find.text('Reset storage (destructive)'));
      await tester.pumpAndSettle();

      expect(find.text('Reset storage?'), findsOneWidget);
      expect(find.text('Are you sure?'), findsNothing);
    });

    testWidgets('cancelling the first dialog aborts -- no second dialog appears',
        (tester) async {
      await pumpKeyOrHeaderCorrupt(tester);

      await tester.tap(find.text('Reset storage (destructive)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel').first);
      await tester.pumpAndSettle();

      expect(find.text('Reset storage?'), findsNothing);
      expect(find.text('Are you sure?'), findsNothing);
    });

    testWidgets(
        'confirming the first dialog shows the second (last-chance) confirmation',
        (tester) async {
      await pumpKeyOrHeaderCorrupt(tester);

      await tester.tap(find.text('Reset storage (destructive)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure?'), findsOneWidget);
    });

    testWidgets('cancelling the second dialog aborts without attempting a reset',
        (tester) async {
      await pumpKeyOrHeaderCorrupt(tester);

      await tester.tap(find.text('Reset storage (destructive)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel').first);
      await tester.pumpAndSettle();

      expect(find.text('Are you sure?'), findsNothing);
      // No busy spinner -- _resetStorage() was never invoked at all.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
        'confirming BOTH dialogs is required before a reset is even attempted',
        (tester) async {
      await pumpKeyOrHeaderCorrupt(tester);

      await tester.tap(find.text('Reset storage (destructive)'));
      await tester.pumpAndSettle();
      // Neither dialog's button is visible before its own step is reached.
      expect(find.text('Yes, delete everything'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Yes, delete everything'), findsOneWidget);

      await tester.tap(find.text('Yes, delete everything'));
      await tester.pump(); // start the async reset attempt (setState(_busy = true))

      // Reaches the guarded action (retireDatabaseFile()/SecureKeyStore.forgetForReset())
      // only after both confirmations -- path_provider/secure_storage platform channels
      // aren't mocked in this widget test, so the async chain never actually resolves,
      // but the busy spinner appearing proves _resetStorage() was genuinely invoked
      // (not skipped) once both confirmations landed.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
