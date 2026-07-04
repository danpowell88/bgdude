/// Navigates the app (in dev mode, so every screen has simulated data) and captures a
/// screenshot of each surface for the HTML docs. Driven by
/// test_driver/screenshot_driver.dart via `flutter drive`.
library;

import 'package:bgdude/app.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    try {
      await binding.takeScreenshot(name);
    } catch (_) {
      // Non-fatal: keep going so one bad frame doesn't abort the run.
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
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
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  testWidgets('capture all screens', (tester) async {
    // Required on Android before screenshots; frames now render to an image.
    await binding.convertFlutterSurfaceToImage();
    await pumpApp(tester);

    // 01 — Today (Your Day panel + dashboard)
    await shot(tester, '01-today');

    // 02 — Today timeline (scroll down to the event stream)
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0;
        i < 8 && find.byType(TimelineEventCard).evaluate().isEmpty;
        i++) {
      await tester.drag(scrollable, const Offset(0, -320));
      await tester.pumpAndSettle();
    }
    await shot(tester, '02-timeline');

    // 03 — Predict
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await shot(tester, '03-predict');

    // 04 — Insights
    await tester.tap(find.byIcon(Icons.lightbulb_outline));
    await shot(tester, '04-insights');

    // 05 — Meals (add a meal so detail has content)
    await tester.tap(find.byIcon(Icons.restaurant_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add meal'));
    await tester.pumpAndSettle();
    await shot(tester, '06-meal-add');
    await tester.enterText(
        find.byKey(const Key('meal-name-field')), 'Pizza night');
    await tester.enterText(find.byKey(const Key('meal-carbs-field')), '70');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save meal'));
    await tester.pumpAndSettle();
    await shot(tester, '05-meals');

    // 07 — Meal detail + pre-bolus coach
    await tester.tap(find.text('Pizza night'));
    await shot(tester, '07-meal-detail');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // Back to Today so the Bolus FAB is present (it's suppressed on the Meals tab).
    await tester.tap(find.byIcon(Icons.today_outlined));
    await tester.pumpAndSettle();

    // 08 — Bolus advisor (with a computed suggestion)
    await tester.tap(find.text('Bolus'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '45');
    await tester.tap(find.text('Calculate suggestion'));
    await shot(tester, '08-bolus');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // 09 — Quick log sheet
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await shot(tester, '09-quicklog');
    await tester.tapAt(const Offset(20, 20)); // dismiss sheet
    await tester.pumpAndSettle();

    // 10 — Settings
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await shot(tester, '10-settings');

    // 11 — Therapy profile
    await tester.tap(find.text('Therapy profile'));
    await shot(tester, '11-therapy');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // 12 — Advanced / model internals
    await tester.scrollUntilVisible(find.text('Model internals'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Model internals'));
    await shot(tester, '12-advanced');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // 13 — Forecast accuracy
    await tester.scrollUntilVisible(find.text('Forecast accuracy'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Forecast accuracy'));
    await shot(tester, '13-accuracy');
  });
}
