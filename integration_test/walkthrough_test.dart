/// Drives the app through a slow, watchable tour (dev mode) while `adb screenrecord`
/// captures the screen — see tools/record_walkthrough.ps1. Uses real-time pauses so the
/// recording shows each screen and the transitions between them.
library;

import 'package:bgdude/app.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> hold([int ms = 1600]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  testWidgets('walkthrough tour', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(NotificationService()),
          onboardingDoneProvider.overrideWith((ref) => true),
          devModeProvider.overrideWith((ref) => true),
        ],
        child: const BgDudeApp(),
      ),
    );
    await tester.pumpAndSettle();
    await hold(2200);

    // Scroll the Today tab to reveal the event stream.
    final scroll = find.byType(Scrollable).first;
    for (var i = 0; i < 4; i++) {
      await tester.drag(scroll, const Offset(0, -260));
      await tester.pumpAndSettle();
      await hold(700);
    }
    await tester.drag(scroll, const Offset(0, 900));
    await tester.pumpAndSettle();
    await hold();

    Future<void> tab(IconData icon) async {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      await hold(2000);
    }

    await tab(Icons.insights_outlined); // Predict
    await tab(Icons.lightbulb_outline); // Insights
    await tab(Icons.restaurant_outlined); // Meals

    // Quick-log sheet.
    await tester.tap(find.byIcon(Icons.today_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await hold(1800);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    // Bolus advisor.
    await tester.tap(find.text('Bolus'));
    await tester.pumpAndSettle();
    await hold();
    await tester.enterText(find.byType(TextField).first, '45');
    await tester.tap(find.text('Calculate suggestion'));
    await tester.pumpAndSettle();
    await hold(2400);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // Settings peek.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await hold(2000);
  });
}
