/// Issue #376: a denied/revoked POST_NOTIFICATIONS grant must be visible.
///
/// The permissions audit found `init()` requested the permission once and nothing
/// ever read the answer, so a refusal left every alert — urgent lows included —
/// silently undeliverable. These pin the tile's display logic: shown only when the OS
/// is blocking notifications, and it does NOT disappear on a tap that didn't actually
/// fix anything (Android shows no dialog after a permanent denial).
///
/// `areNotificationsEnabled` / `requestNotificationsPermission` wrap a real platform
/// channel with no implementation in a plain unit-test binding, so the fake makes both
/// controllable — the same seam settings_screen_exact_alarm_test.dart uses.
library;

import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService({
    required bool enabled,
    this.grantOnRequest = false,
  }) : _enabled = enabled;

  bool _enabled;

  /// Whether the simulated user grants when the dialog is shown. False models a
  /// PERMANENT denial, where Android resolves the request with no UI at all.
  final bool grantOnRequest;
  int requestCount = 0;

  @override
  Future<bool> areNotificationsEnabled() async => _enabled;

  /// The exact-alarm tile shares this screen and this service; without stubbing it
  /// the real implementation reaches for a platform channel that doesn't exist in a
  /// unit-test binding. True keeps that tile hidden so it can't collide with the
  /// assertions below.
  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> requestNotificationsPermission() async {
    requestCount++;
    if (grantOnRequest) _enabled = true;
  }
}

Future<void> _pumpSettings(
  WidgetTester tester,
  NotificationService service, {
  Future<void> Function()? openSettings,
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 1400));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(service),
        if (openSettings != null)
          appSettingsOpenerProvider.overrideWithValue(openSettings),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => TestWidgetsFlutterBinding.instance.reset());

  testWidgets('the warning is shown when Android is blocking notifications',
      (tester) async {
    await _pumpSettings(tester, _FakeNotificationService(enabled: false));

    expect(find.text('Alerts are turned off'), findsOneWidget);
    // The wording has to name the consequence, not just the setting — "notifications
    // are off" reads as cosmetic; "no alerts including urgent lows" does not.
    expect(
      find.textContaining('including urgent lows'),
      findsOneWidget,
      reason: 'the tile must state that alerting is entirely disabled',
    );
  });

  testWidgets('no warning is shown when notifications are enabled',
      (tester) async {
    await _pumpSettings(tester, _FakeNotificationService(enabled: true));

    // A permanent "all good" row is noise; this tile exists only to warn.
    expect(find.text('Alerts are turned off'), findsNothing);
  });

  testWidgets('tapping requests the permission and clears once granted',
      (tester) async {
    final service =
        _FakeNotificationService(enabled: false, grantOnRequest: true);
    await _pumpSettings(tester, service);
    expect(find.text('Alerts are turned off'), findsOneWidget);

    await tester.tap(find.text('Alerts are turned off'));
    await tester.pumpAndSettle();

    expect(service.requestCount, 1);
    expect(find.text('Alerts are turned off'), findsNothing);
  });

  testWidgets('the warning STAYS after a tap that did not grant anything',
      (tester) async {
    // Permanent denial: Android resolves the request without showing any dialog.
    // Hiding the tile on tap would tell the user alerts were restored when they
    // were not — the one failure mode worse than not warning at all.
    final service =
        _FakeNotificationService(enabled: false, grantOnRequest: false);
    await _pumpSettings(tester, service);

    await tester.tap(find.text('Alerts are turned off'));
    await tester.pumpAndSettle();

    expect(service.requestCount, 1);
    expect(find.text('Alerts are turned off'), findsOneWidget,
        reason: 'the tap changed nothing, so the warning must persist');
  });

  testWidgets('after a request that changes nothing, it offers system settings',
      (tester) async {
    // Permanent denial: Android resolves the request with no dialog. Re-requesting
    // can never succeed from here, so continuing to tell the user to tap and turn
    // them on would be advice that cannot work (issue #376 AC#6).
    var opened = 0;
    final service =
        _FakeNotificationService(enabled: false, grantOnRequest: false);
    await _pumpSettings(tester, service, openSettings: () async => opened++);

    await tester.tap(find.text('Alerts are turned off'));
    await tester.pumpAndSettle();

    expect(service.requestCount, 1);
    expect(find.textContaining('open system settings'), findsOneWidget,
        reason: 'the tile must change its advice once asking stopped working');
    expect(opened, 0, reason: 'the first tap asks; it does not jump to settings');

    // The second tap now deep-links instead of asking again.
    await tester.tap(find.text('Alerts are turned off'));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(service.requestCount, 1,
        reason: 'it must not keep firing a request that provably does nothing');
  });

}
