/// The permissions screen's list (issue #376).
library;

import 'package:bgdude/state/permission_audit.dart';
import 'package:bgdude/ui/widgets/permission_audit_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _notifications = AppPermission(
  id: 'notification',
  title: 'Notifications',
  why: 'Glucose alarms are delivered as notifications.',
  whatBreaks: 'No low or high alarms at all.',
  severity: PermissionSeverity.critical,
  requestedAt: 'Onboarding',
);

const _camera = AppPermission(
  id: 'camera',
  title: 'Camera',
  why: 'Scans barcodes.',
  whatBreaks: 'Scanning unavailable; type it in instead.',
  severity: PermissionSeverity.optional,
  requestedAt: 'On first use',
);

Future<List<AppPermission>> _pump(
  WidgetTester tester,
  List<AuditedPermission> audit,
) async {
  final fixed = <AppPermission>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PermissionAuditList(audit: audit, onFix: fixed.add),
    ),
  ));
  await tester.pumpAndSettle();
  return fixed;
}

void main() {
  testWidgets('a granted permission shows no warning and no fix button',
      (tester) async {
    await _pump(tester, [
      (permission: _notifications, grant: PermissionGrant.granted),
    ]);

    expect(find.text('Granted'), findsOneWidget);
    expect(find.text('Open settings'), findsNothing);
    expect(find.textContaining('is missing'), findsNothing);
  });

  testWidgets('a denied critical permission warns with the consequence',
      (tester) async {
    await _pump(tester, [
      (permission: _notifications, grant: PermissionGrant.denied),
    ]);

    // The banner must say what breaks, not just that something is denied.
    expect(find.textContaining('No low or high alarms at all'), findsWidgets);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('a denied OPTIONAL permission does not raise the banner',
      (tester) async {
    // Otherwise the warning is permanently on and stops meaning anything.
    await _pump(tester, [
      (permission: _notifications, grant: PermissionGrant.granted),
      (permission: _camera, grant: PermissionGrant.denied),
    ]);

    expect(find.textContaining('is missing.'), findsNothing);
    // It still offers the fix on the tile itself.
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('unknown reads as unknown, not as denied', (tester) async {
    await _pump(tester, [
      (permission: _notifications, grant: PermissionGrant.unknown),
    ]);

    expect(find.textContaining("Can't tell from here"), findsOneWidget);
    expect(find.textContaining('is missing'), findsNothing);
  });

  testWidgets('tapping the fix action reports which permission', (tester) async {
    final fixed = await _pump(tester, [
      (permission: _notifications, grant: PermissionGrant.permanentlyDenied),
    ]);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(fixed.single.id, 'notification');
  });

  testWidgets('several gaps are summarised rather than listed twice',
      (tester) async {
    await _pump(tester, [
      (permission: _notifications, grant: PermissionGrant.denied),
      (
        permission: const AppPermission(
          id: 'ignoreBatteryOptimizations',
          title: 'Unrestricted battery use',
          why: 'Keeps the pump connection alive.',
          whatBreaks: 'Doze suspends monitoring.',
          severity: PermissionSeverity.critical,
          requestedAt: 'Onboarding',
        ),
        grant: PermissionGrant.denied
      ),
    ]);

    expect(find.textContaining('2 required permissions are missing'),
        findsOneWidget);
  });

  testWidgets('the list explains why location is even listed', (tester) async {
    await _pump(tester, [
      (permission: _notifications, grant: PermissionGrant.granted),
    ]);

    expect(find.textContaining('never uses your location'), findsOneWidget);
  });
}
