import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TASK-239: [NotificationService.canScheduleExactAlarms]/
/// [NotificationService.requestExactAlarmPermission] wrap a real
/// platform-channel call that has no implementation in a plain unit-test
/// binding -- this fake makes both controllable so the tile's DISPLAY logic
/// (shown only when denied, hidden once granted) is exercised directly
/// rather than through the untestable platform channel.
class _FakeNotificationService extends NotificationService {
  _FakeNotificationService({required bool canExact}) : _canExact = canExact;

  bool _canExact;
  int requestCount = 0;

  @override
  Future<bool> canScheduleExactAlarms() async => _canExact;

  @override
  Future<void> requestExactAlarmPermission() async {
    requestCount++;
    _canExact = true; // simulate the user granting it in system settings
  }
}

Future<void> _pumpSettings(
    WidgetTester tester, NotificationService service) async {
  await tester.binding.setSurfaceSize(const Size(500, 1400));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [notificationServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => TestWidgetsFlutterBinding.instance.reset());

  testWidgets(
      'the exact-alarm tile is shown when the permission is denied',
      (tester) async {
    await _pumpSettings(tester, _FakeNotificationService(canExact: false));

    expect(find.text('Allow exact alarms'), findsOneWidget);
  });

  testWidgets(
      'the exact-alarm tile is hidden once the permission is already granted '
      '-- it must never nag once addressed', (tester) async {
    await _pumpSettings(tester, _FakeNotificationService(canExact: true));

    expect(find.text('Allow exact alarms'), findsNothing);
  });

  testWidgets(
      'tapping the tile requests the permission and hides once granted',
      (tester) async {
    final service = _FakeNotificationService(canExact: false);
    await _pumpSettings(tester, service);

    await tester.dragUntilVisible(
      find.text('Allow exact alarms'),
      find.byType(Scrollable),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow exact alarms'));
    await tester.pumpAndSettle();

    expect(service.requestCount, 1);
    expect(find.text('Allow exact alarms'), findsNothing);
  });
}
