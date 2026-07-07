/// TASK-252 AC#3: on-device coverage for the storage-recovery screen -- reached by
/// tapping the storage-failed banner, and its destructive reset needs two
/// confirmations before retireDatabaseFile()/SecureKeyStore.forgetForReset() run for
/// real (this needs a device: path_provider + flutter_secure_storage are native
/// platform channels that widget tests can't exercise end-to-end -- see
/// test/db_recovery_screen_test.dart for the logic-level coverage that CAN run
/// headless).
/// Run with: flutter test integration_test/db_recovery_screen_test.dart -d <device-id>
library;

import 'package:bgdude/app.dart';
import 'package:bgdude/data/db_open_diagnosis.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _pumpAppWithDbFailure(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(NotificationService()),
        onboardingDoneProvider.overrideWith((ref) => true),
        devModeProvider.overrideWith((ref) => false),
        dbOpenErrorProvider.overrideWithValue('keyOrHeaderCorrupt'),
        dbOpenDiagnosisProvider
            .overrideWithValue(DbOpenDiagnosis.keyOrHeaderCorrupt),
        dbOpenSalvageDbProvider.overrideWithValue(null),
      ],
      child: const BgDudeApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'tapping the storage banner reaches the recovery screen, and reset '
      'requires two confirmations before attempting anything destructive',
      (tester) async {
    await _pumpAppWithDbFailure(tester);

    // The storage-failed banner is visible and tappable.
    expect(find.textContaining('keyOrHeaderCorrupt'), findsOneWidget);
    await tester.tap(find.textContaining('keyOrHeaderCorrupt'));
    await tester.pumpAndSettle();

    expect(find.text('Storage recovery'), findsOneWidget);
    expect(find.text('Storage key mismatch or damage'), findsOneWidget);
    // Not salvageable -- no export option for this diagnosis.
    expect(find.text('Export what\'s still readable'), findsNothing);

    await tester.tap(find.text('Reset storage (destructive)'));
    await tester.pumpAndSettle();
    expect(find.text('Reset storage?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure?'), findsOneWidget);

    // Cancel here -- the real file must be untouched (no on-device assertion of the
    // filesystem in this smoke test; the guarded-action-only-fires-after-both-
    // confirmations behaviour itself is pinned headlessly in
    // test/db_recovery_screen_test.dart).
    await tester.tap(find.text('Cancel').first);
    await tester.pumpAndSettle();
    expect(find.text('Are you sure?'), findsNothing);
  });
}
