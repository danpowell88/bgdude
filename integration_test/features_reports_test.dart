/// Emulator coverage for the Reports hub and each of the seven reports. Opens every
/// report from the hub, asserts it renders, and returns — exercising the full report
/// stack against the simulated day's confirmed data.
///
/// Run with: flutter test integration_test/features_reports_test.dart -d <device-id>
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

/// Open the report card titled [title] from the hub, assert its screen renders, pop back.
Future<void> _openReport(WidgetTester tester, String title) async {
  final card = find.text(title);
  await tester.scrollUntilVisible(card, 150,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
  // On the detail screen: a Back button and the report's own title.
  expect(find.byTooltip('Back'), findsOneWidget);
  expect(find.text(title), findsWidgets);
  await tester.pageBack();
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reports hub opens each of the seven reports', (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Reports');
    expect(find.text('Reports'), findsWidgets);

    for (final report in const [
      'Glucose report',
      'Insulin report',
      'Meals report',
      'Therapy report',
      'Correlations',
      'Events journal',
      'Model performance',
    ]) {
      await _openReport(tester, report);
    }
  });

  testWidgets('glucose report renders AGP + metrics from seeded demo data',
      (tester) async {
    await pumpDemoApp(tester);
    await openSettingsScreen(tester, 'Reports');
    final card = find.text('Glucose report');
    await tester.scrollUntilVisible(card, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(card);
    await tester.pumpAndSettle();
    // Demo mode seeds ~3 weeks of history, so the AGP + GMI compute (not the empty state).
    expect(find.text('GMI'), findsWidgets);
    expect(find.text('Not enough data for an AGP curve.'), findsNothing);
  });
}
