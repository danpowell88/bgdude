/// Emulator coverage for every Settings sub-screen and the settings that change app-wide
/// behaviour. Boots the app in demo mode and opens each destination, asserting a stable
/// heading (and, where relevant, a feature-specific control) renders.
///
/// Run with: flutter test integration_test/features_settings_test.dart -d <device-id>
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Profile screen opens', (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Profile');
    expect(find.text('Profile'), findsWidgets);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('Confirm events inbox opens', (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Confirm events');
    expect(find.text('Confirm events'), findsWidgets);
  });

  testWidgets('Notifications: thresholds and quiet hours', (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Notifications');
    expect(find.text('Notifications'), findsWidgets);
    expect(find.text('Alert thresholds'), findsOneWidget);
    expect(find.text('Quiet hours'), findsOneWidget);
  });

  testWidgets('Exercise mode can be announced', (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Exercise mode');
    expect(find.text('Exercise mode'), findsWidgets);
    expect(find.text('Start exercise mode'), findsOneWidget);
  });

  testWidgets('Medication / steroid mode opens', (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Medication / steroid mode');
    expect(find.text('Medication mode'), findsWidgets);
    expect(find.byType(Switch), findsWidgets);
  });

  testWidgets('Pump screen shows live status incl. Control-IQ', (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Pump');
    expect(find.text('Pump'), findsWidgets);
    // The simulated pump reports the closed loop active — our Control-IQ row.
    expect(find.text('Control-IQ'), findsOneWidget);
    expect(find.text('Insulin today'), findsOneWidget);
  });

  testWidgets('Weather settings open', (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Weather');
    expect(find.text('Weather'), findsWidgets);
    expect(find.text('Use weather'), findsOneWidget);
  });

  testWidgets('Basal suggestions open', (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Basal suggestions');
    expect(find.text('Basal suggestions'), findsWidgets);
  });

  testWidgets('Forecast accuracy opens', (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Forecast accuracy');
    expect(find.text('Forecast accuracy'), findsWidgets);
  });

  testWidgets('Therapy profile editor lists a segment', (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Therapy profile');
    expect(find.text('Add segment'), findsOneWidget);
    expect(find.textContaining('Basal'), findsWidgets);
  });

  testWidgets('Model internals renders its sections', (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Model internals');
    expect(find.text('Effective sensitivity'), findsOneWidget);
    expect(find.text('Forecaster'), findsOneWidget);
    expect(find.text('Clarke error grid'), findsOneWidget);
    // The forecaster card always states whether the learned residual is live;
    // after a training run it also shows candidate/baseline (and, once an
    // incumbent exists, active) RMSE plus the gate's keep/reject reasons.
    expect(find.text('Learned residual'), findsOneWidget);
  });

  testWidgets('changing units to mg/dL propagates to the Pump screen',
      (tester) async {
    await pumpDemoApp(tester);
    await openSettings(tester);
    await tester.tap(find.text('mg/dL'));
    await tester.pumpAndSettle();
    await tapListItem(tester, 'Pump');
    // The glucose row now renders in the newly-chosen unit.
    expect(find.textContaining('mg/dL'), findsWidgets);
  });

  testWidgets('advanced mode toggles', (tester) async {
    await pumpDemoApp(tester);
    await openSettings(tester);
    final advanced = find.widgetWithText(SwitchListTile, 'Advanced mode');
    await tester.scrollUntilVisible(advanced, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(advanced);
    await tester.pumpAndSettle();
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    // Toggling doesn't crash and the control is still present.
    expect(advanced, findsOneWidget);
  });
}
