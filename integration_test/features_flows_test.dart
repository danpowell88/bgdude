/// Emulator coverage for interactive flows that aren't reached through Settings: the
/// Today "Explain this reading" screen, quick-log variants, the Predict what-if explorer,
/// and leaving demo mode from the header.
///
/// Run with: flutter test integration_test/features_flows_test.dart -d <device-id>
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // TASK-220: KvStore is a process-global static -- without this, an earlier test's
  // app flags/prefs (in this file or another run in the same process) leak in.
  setUp(setUpDemoHarness);

  testWidgets('Today → Explain this reading opens the explainer',
      (tester) async {
    await pumpDemoApp(tester);
    final button = find.text('Explain this reading');
    await tester.scrollUntilVisible(button, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    // The explainer screen (its own AppBar title) is now on top.
    expect(find.text('Explain this reading'), findsWidgets);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('quick-log alcohol closes the sheet (opens overnight watch)',
      (tester) async {
    await pumpDemoApp(tester);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    expect(find.text('Quick log'), findsOneWidget);
    await tester.tap(find.text('🍷 Alcohol'));
    await tester.pumpAndSettle();
    expect(find.text('Quick log'), findsNothing);
  });

  testWidgets('Predict tab exposes the what-if explorer with sliders',
      (tester) async {
    await pumpDemoApp(tester);
    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();

    final whatIf = find.text('What-if explorer');
    await tester.scrollUntilVisible(whatIf, 250,
        scrollable: find.byType(Scrollable).first);
    expect(whatIf, findsOneWidget);
    expect(find.byType(Slider), findsWidgets);
    // TASK-234 class of bug: scrollUntilVisible stops once the label enters the
    // viewport, but the Slider itself (further down the same section) can still sit
    // at the edge -- ensureVisible brings it fully on-screen before drag() derives a
    // hit-test offset against it.
    await tester.ensureVisible(find.byType(Slider).first);
    await tester.pumpAndSettle();

    // TASK-167: raising carbs must move the projection UP, not merely re-render.
    double? endingMgdl() {
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final m = RegExp(r'ending ([\d.]+)').firstMatch(t.data ?? '');
        if (m != null) return double.parse(m.group(1)!);
      }
      return null;
    }

    // A big carb-only nudge so the direction is unambiguous.
    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pumpAndSettle();
    final withSomeCarbs = endingMgdl();
    expect(withSomeCarbs, isNotNull,
        reason: 'the what-if projection line should be visible');

    await tester.drag(find.byType(Slider).first, const Offset(120, 0));
    await tester.pumpAndSettle();
    final withMoreCarbs = endingMgdl();
    expect(withMoreCarbs, isNotNull);
    expect(withMoreCarbs!, greaterThan(withSomeCarbs!),
        reason: 'more carbs must raise the projected ending glucose');
  });

  testWidgets('Exit demo from the header leaves demo mode', (tester) async {
    await pumpDemoApp(tester);
    expect(find.text('DEMO'), findsOneWidget);

    await tester.tap(find.text('Exit demo'));
    // Don't pumpAndSettle: leaving demo starts a live scan whose periodic events
    // would keep the frame pipeline busy. A few bounded frames are enough.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('DEMO'), findsNothing);
    expect(find.text('Exit demo'), findsNothing);
  });

  testWidgets(
      'Today → prediction chart event marker opens Explain this reading '
      '(TASK-155)', (tester) async {
    // The simulated day's nocturnal compression low (~03:10, see sim_data.dart)
    // lands ~50 min before this fixed "now" -- inside the prediction chart's
    // -150..0 min history window -- so a marker is guaranteed to render.
    await pumpDemoApp(tester, fixedNow: DateTime(2026, 7, 10, 4, 0));

    final marker = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('event-marker-'));
    await tester.scrollUntilVisible(marker, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(marker, findsWidgets);

    await tester.tap(marker.first);
    await tester.pumpAndSettle();

    expect(find.text('Explain this reading'), findsWidgets);
    expect(find.byTooltip('Back'), findsOneWidget);
  });
}
