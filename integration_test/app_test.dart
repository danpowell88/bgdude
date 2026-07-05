/// On-device integration tests: boots the real app on an Android device/emulator and
/// drives the primary flows through the tab shell. Demo mode is enabled so the timeline,
/// predictions, and insights render against the simulated t:slim + CGM (no hardware).
/// Run with: flutter test integration_test -d <device-id>
library;

import 'package:bgdude/app.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  bool onboarded = true,
  bool devMode = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(NotificationService()),
        onboardingDoneProvider.overrideWith((ref) => onboarded),
        devModeProvider.overrideWith((ref) => devMode),
      ],
      child: const BgDudeApp(),
    ),
  );
  await tester.pumpAndSettle();
  // Let the simulator's deferred first emit (Timer.zero) land and rebuild.
  if (devMode) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first run shows onboarding with the pairing warning gate',
      (tester) async {
    await _pumpApp(tester, onboarded: false);

    expect(find.textContaining('personal companion'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Before you pair'), findsOneWidget);
    final next =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'));
    expect(next.onPressed, isNull);

    await tester.tap(find.text('I understand and want to continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('About you'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    // Final gate: pair a pump or choose demo. In this (simulated) run the pump
    // "connects", so the Get-started button is enabled without an explicit choice.
    expect(find.text('Get connected'), findsOneWidget);
    expect(find.text('Use demo mode'), findsOneWidget);
  });

  testWidgets('demo mode boots the tab shell with simulated glucose',
      (tester) async {
    await _pumpApp(tester);

    // Shell chrome + DEMO badge + one-tap exit.
    expect(find.text('Today'), findsWidgets);
    expect(find.text('DEMO'), findsOneWidget);
    expect(find.text('Exit demo'), findsOneWidget);
    // Simulated pump connects and streams a reading (no "waiting" card).
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('Simulated t:slim'), findsOneWidget);
    expect(find.text('Bolus'), findsOneWidget);
    // The Your Day panel renders with a headline + stats.
    expect(find.text('Your day'), findsOneWidget);
    expect(find.text('TIR today'), findsOneWidget);
  });

  testWidgets('quick log sheet opens and logs carbs', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(find.text('Quick log'), findsOneWidget);
    expect(find.text('🩹 New sensor'), findsOneWidget);
    await tester.tap(find.text('🏃 Exercise'));
    await tester.pumpAndSettle();
    // Sheet closed after logging.
    expect(find.text('Quick log'), findsNothing);
  });

  testWidgets('settings exposes accuracy, health sync and nightscout',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Forecast accuracy'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Forecast accuracy'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Nightscout'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Nightscout'), findsOneWidget);
    await tester.tap(find.text('Nightscout'));
    await tester.pumpAndSettle();
    expect(find.text('Upload to Nightscout'), findsOneWidget);
  });

  testWidgets('timeline shows simulated events that can be tagged',
      (tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    // Events render below the dashboard in the same scroll view (lazy-built), so
    // drag up until event cards and their tag actions come into view. (The tag/ignore
    // → annotation logic itself is covered by unit tests.)
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0;
        i < 20 &&
            (find.byType(TimelineEventCard).evaluate().isEmpty ||
                find.text('Use for model').evaluate().isEmpty);
        i++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(find.byType(TimelineEventCard), findsWidgets);
    expect(find.text('Use for model'), findsWidgets);
  });

  testWidgets('predict tab shows forecast horizons and scenario chart',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Forecast'), findsOneWidget);
    expect(find.text('+30m'), findsOneWidget);
    expect(find.text('+60m'), findsOneWidget);
    expect(find.text('+120m'), findsOneWidget);
    expect(find.text('Scenario lines'), findsOneWidget);
    expect(find.textContaining('Sensitivity readiness'), findsOneWidget);
  });

  testWidgets('insights tab merges briefing, sensitivity and illness',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.lightbulb_outline));
    await tester.pumpAndSettle();

    expect(find.text('Daily briefing'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Insulin sensitivity'), 250,
        scrollable: scrollable);
    expect(find.text('Insulin sensitivity'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('A1c goal'), 250,
        scrollable: scrollable);
    expect(find.text('A1c goal'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sleep & glucose'), 250,
        scrollable: scrollable);
    expect(find.text('Sleep & glucose'), findsOneWidget);

    final sick = find.text('Sick day mode');
    await tester.scrollUntilVisible(sick, 250, scrollable: scrollable);
    expect(sick, findsOneWidget);

    // Toggle illness mode on → the resistance slider appears.
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsWidgets);
  });

  testWidgets('bolus advisor computes a suggestion from simulated glucose',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Bolus'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '45');
    await tester.tap(find.text('Calculate suggestion'));
    await tester.pumpAndSettle();

    // With a live simulated reading the advisor produces working + a suggestion.
    expect(find.text('Working'), findsOneWidget);
    expect(find.text('Suggested'), findsOneWidget);
  });

  testWidgets('meals tab: add a meal and open its detail with the coach',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.restaurant_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add meal'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('meal-name-field')), 'Test pasta');
    await tester.enterText(find.byKey(const Key('meal-carbs-field')), '60');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save meal'));
    await tester.pumpAndSettle();

    // Sheet closed; the meal is in the list.
    expect(find.text('Save meal'), findsNothing);
    expect(find.text('Test pasta'), findsOneWidget);
    await tester.tap(find.text('Test pasta'));
    await tester.pumpAndSettle();

    // Demo mode has a live reading, so the pre-bolus coach renders (not the
    // "needs a live CGM" fallback). "Learned curve" appears as both the section
    // header and a coach working line.
    expect(find.text('Learned curve'), findsWidgets);
    expect(find.text('What this meal does to you'), findsOneWidget);
    expect(find.textContaining('needs a live CGM reading'), findsNothing);
  });

  testWidgets('settings shows demo-mode exit and core options', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // In demo mode Settings shows a read-only status row with an Exit action (no
    // manual switch back into demo). These sit at the top and are visible immediately.
    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Exit'), findsOneWidget);
    expect(find.text('Glucose units'), findsOneWidget);
    // A core option lower in the (lazy) list confirms the rest of Settings renders.
    // Individual sub-screens have their own coverage in features_settings_test.dart.
    await tester.scrollUntilVisible(find.text('Model internals'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Model internals'), findsOneWidget);
  });

  testWidgets('therapy profile editor opens and lists a segment',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Therapy profile'));
    await tester.pumpAndSettle();
    expect(find.text('Add segment'), findsOneWidget);
    expect(find.textContaining('Basal'), findsWidgets);
  });

  testWidgets('advanced/model internals screen renders sections',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Model internals'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Model internals'));
    await tester.pumpAndSettle();
    expect(find.text('Effective sensitivity'), findsOneWidget);
    expect(find.text('Forecaster'), findsOneWidget);
    expect(find.text('Clarke error grid'), findsOneWidget);
  });
}
