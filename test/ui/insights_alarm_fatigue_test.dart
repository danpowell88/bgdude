/// The alarm-fatigue card on Insights (issue #171, AC#2).
///
/// Overrides `alarmFatigueProvider` with a fixed rollup rather than seeding events and
/// pinning a clock: the rollup arithmetic already has its own tests, and this is about
/// what the card renders. It also keeps the test independent of when the suite runs.
library;

import 'package:bgdude/insights/alarm_fatigue.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/widgets/alarm_fatigue_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AlarmFatigueRollup _rollup({
  required int total,
  Map<NotificationCategory, int> perCategory = const {},
  double overnightShare = 0,
  int previousTotal = 0,
}) =>
    AlarmFatigueRollup(
      total: total,
      perCategory: perCategory,
      overnightShare: overnightShare,
      previousTotal: previousTotal,
    );

Future<void> _pump(WidgetTester tester, AlarmFatigueRollup rollup) async {
  await tester.binding.setSurfaceSize(const Size(500, 2000));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alarmFatigueProvider.overrideWith((ref) async => rollup),
      ],
      // The card alone, not the whole Insights screen: the screen pulls in the
      // repository, health features and the sensitivity model, none of which this
      // card reads, and overriding all of them would test the harness not the card.
      child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AlarmFatigueCard()))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => TestWidgetsFlutterBinding.instance.reset());

  testWidgets('shows the count, overnight share and per-category breakdown',
      (tester) async {
    await _pump(
      tester,
      _rollup(
        total: 12,
        perCategory: const {
          NotificationCategory.predictedLow: 9,
          NotificationCategory.predictedHigh: 3,
        },
        overnightShare: 0.75,
        previousTotal: 5,
      ),
    );

    expect(find.text('12 alerts this week'), findsOneWidget);
    expect(find.textContaining('75% overnight'), findsOneWidget);
    // The counts are what make it actionable — "12 alerts" alone doesn't say which
    // threshold to look at.
    expect(find.textContaining('Low predicted ×9'), findsOneWidget);
    expect(find.textContaining('High predicted ×3'), findsOneWidget);
  });

  testWidgets('a noisier week says how much more', (tester) async {
    await _pump(tester,
        _rollup(total: 12, overnightShare: 0, previousTotal: 5));

    expect(find.textContaining('7 more than last week'), findsOneWidget);
  });

  testWidgets('a quieter week says how much fewer', (tester) async {
    // Separate test rather than a second pump in the one above: re-pumping a new
    // ProviderScope into the same tester reuses element state and the override
    // doesn't reliably take, which made this pass or fail on widget identity
    // rather than on the behaviour being asserted.
    await _pump(tester,
        _rollup(total: 4, overnightShare: 0, previousTotal: 10));

    expect(find.textContaining('6 fewer than last week'), findsOneWidget);
  });

  testWidgets('an unchanged week says so rather than claiming a direction',
      (tester) async {
    // "+0 more than last week" reads as a finding when it is the absence of one.
    await _pump(tester,
        _rollup(total: 8, overnightShare: 0, previousTotal: 8));

    expect(find.textContaining('same as last week'), findsOneWidget);
    expect(find.textContaining('0 more'), findsNothing);
  });

  testWidgets('a quiet week renders nothing at all', (tester) async {
    // A card reading "0 alerts this week" every day trains the eye to skip this
    // part of the screen, which is the opposite of what the card is for.
    await _pump(tester, _rollup(total: 0));

    expect(find.textContaining('alerts this week'), findsNothing);
  });

  testWidgets('a dominated week surfaces the suggestion', (tester) async {
    await _pump(
      tester,
      _rollup(
        total: 10,
        perCategory: const {NotificationCategory.predictedLow: 9},
        overnightShare: 0.8,
        previousTotal: 2,
      ),
    );

    // The suggestion is the actionable half: which knob to turn.
    expect(find.textContaining('threshold or repeat interval'), findsOneWidget);
  });
}
