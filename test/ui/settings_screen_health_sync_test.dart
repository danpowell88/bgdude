import 'package:bgdude/data/health_sync.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The manual "Sync health data now" tap awaited two unguarded plugin
/// calls with no try/catch — a PlatformException from Health Connect used to escape
/// as an unhandled exception instead of surfacing to the user.
class _ThrowingHealthSync extends HealthSyncService {
  @override
  Future<bool> requestPermissions() async =>
      throw Exception('Health Connect not installed');
}

/// TASK-239: SettingsScreen now also reads notificationServiceProvider (the
/// exact-alarm tile) -- that provider deliberately `throw`s by default
/// outside main(), so any test rendering SettingsScreen must override it too.
/// `canScheduleExactAlarms` returning true keeps the new tile hidden, so it
/// doesn't interfere with this test's own target (the health-sync tile).
class _FakeNotificationService extends NotificationService {
  @override
  Future<bool> canScheduleExactAlarms() async => true;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => TestWidgetsFlutterBinding.instance.reset());

  testWidgets('a failed health sync shows an error snackbar instead of throwing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthSyncServiceProvider.overrideWithValue(_ThrowingHealthSync()),
          notificationServiceProvider
              .overrideWithValue(_FakeNotificationService()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The tile is below the fold — ListView only builds children near the viewport, so
    // it isn't in the element tree yet (ensureVisible needs an existing element).
    await tester.dragUntilVisible(
      find.text('Sync health data now'),
      find.byType(Scrollable),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sync health data now'));
    await tester.pump(); // start the async tap
    await tester.pump(const Duration(milliseconds: 50)); // let it fail
    await tester.pump(const Duration(seconds: 1)); // let the SnackBar animate in

    expect(find.textContaining('Health sync failed'), findsOneWidget);
  });
}
