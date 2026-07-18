/// The history decode-coverage screen (issue #94).
library;

import 'package:bgdude/pump/history_log_coverage.dart';
import 'package:bgdude/ui/history_coverage_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: HistoryCoverageScreen()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('states the real coverage, not a hardcoded figure', (tester) async {
    await _pump(tester);

    expect(
      find.text('$decodedHistoryLogCount of ${historyLogTypes.length} '
          'event types decoded'),
      findsOneWidget,
    );
    // The distinction that stops an undecoded event reading as a fault.
    expect(find.textContaining('still stream from the pump'), findsOneWidget);
  });

  testWidgets('filtering narrows the list', (tester) async {
    await _pump(tester);

    await tester.enterText(
        find.byKey(const Key('history-coverage-filter')), 'Bolus');
    await tester.pumpAndSettle();

    // Only matching types survive — and at least one does, so this isn't passing
    // on an empty list.
    final matching =
        historyLogTypes.where((t) => t.name.toLowerCase().contains('bolus'));
    expect(matching, isNotEmpty);
    expect(find.text(matching.first.name), findsOneWidget);
    final nonMatching =
        historyLogTypes.firstWhere((t) => !t.name.toLowerCase().contains('bolus'));
    expect(find.text(nonMatching.name), findsNothing);
  });

  testWidgets('the decoded-only toggle hides undecoded types', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('history-coverage-decoded-only')));
    await tester.pumpAndSettle();

    // Every visible row is a decoded one.
    expect(find.text('Raw only — not stored as therapy data'), findsNothing);
    expect(find.text('Decoded'), findsWidgets);
  });

  testWidgets('filtering is case-insensitive', (tester) async {
    await _pump(tester);

    await tester.enterText(
        find.byKey(const Key('history-coverage-filter')), 'bolus');
    await tester.pumpAndSettle();

    final matching =
        historyLogTypes.where((t) => t.name.toLowerCase().contains('bolus'));
    expect(find.text(matching.first.name), findsOneWidget);
  });

  testWidgets('a filter matching nothing shows an empty list, not a crash',
      (tester) async {
    await _pump(tester);

    await tester.enterText(
        find.byKey(const Key('history-coverage-filter')), 'zzzznotathing');
    await tester.pumpAndSettle();

    // No event-type rows at all. (Checked by name rather than by ListTile: the
    // "decoded only" switch is itself a ListTile and would mask an empty list.)
    for (final t in historyLogTypes.take(20)) {
      expect(find.text(t.name), findsNothing, reason: t.name);
    }
    // The header is still there, so the screen hasn't blanked.
    expect(find.textContaining('event types decoded'), findsOneWidget);
  });
}
