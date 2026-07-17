import 'package:bgdude/state/providers.dart';
import 'package:bgdude/timeline/day_event.dart';
import 'package:bgdude/ui/timeline_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/samples.dart';

// TASK-155 coverage: TimelineEventCard is the shared card the commit's explainDayEvent
// extraction was pulled out of ("reused by both chart overlays so a marker tap behaves
// identically to the Timeline's own 'Explain' button"). These widget tests exercise the
// card's own render + tag/explain behaviour directly, which the touched-file lcov gap
// showed was entirely untested at the unit-test level (only reachable before via the
// on-device integration suite).

DayEvent _event({
  String id = 'e1',
  DayEventType type = DayEventType.high,
  bool explainable = true,
  ModelDisposition disposition = ModelDisposition.use,
  IgnoreReason? ignoreReason,
}) =>
    DayEvent(
      id: id,
      type: type,
      time: DateTime(2026, 7, 10, 9, 0),
      title: 'A high',
      detail: 'Rose to 210 mg/dL',
      explainable: explainable,
      disposition: disposition,
      ignoreReason: ignoreReason,
    );

final _emptyDayData = DayData(
  start: DateTime(2026, 7, 10),
  end: DateTime(2026, 7, 11),
  cgm: const [],
  boluses: const [],
  basal: const [],
  carbs: const [],
  settings: testTherapySettings(),
  context: null,
  isSimulated: false,
);

Widget _host(Widget child) => ProviderScope(
      overrides: [dayDataProvider.overrideWithValue(_emptyDayData)],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders title/detail/type and hides the chip while in-use',
      (tester) async {
    await tester.pumpWidget(_host(TimelineEventCard(event: _event())));

    expect(find.text('A high'), findsOneWidget);
    expect(find.text('Rose to 210 mg/dL'), findsOneWidget);
    expect(find.textContaining('High'), findsWidgets);
    expect(find.text('Use for model'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('shows the ignored disposition chip with its reason label',
      (tester) async {
    await tester.pumpWidget(_host(TimelineEventCard(
      event: _event(
        disposition: ModelDisposition.ignore,
        ignoreReason: IgnoreReason.compressionLow,
      ),
    )));

    expect(find.text('Compression low'), findsOneWidget);
    expect(find.text('Ignored'), findsOneWidget);
  });

  testWidgets(
      'tapping Explain on a non-compression-low event opens Explain this '
      'reading (exercises the daytime wasAsleep branch)', (tester) async {
    // 09:00 is outside the default 23:00-07:00 sleep window and the event type
    // is not compressionLow, so explainDayEvent's wasAsleep ternary evaluates
    // defaultAsleepAt(...) rather than short-circuiting on the type check.
    await tester.pumpWidget(_host(TimelineEventCard(event: _event())));

    await tester.tap(find.text('Explain'));
    await tester.pumpAndSettle();

    expect(find.text('Explain this reading'), findsOneWidget);
    // With no CGM/pump data at all in the window, every hypothesis scores
    // below the cutoff, so the explainer falls back to its "No clear cause"
    // explanation (with no suggestedAnnotation -- no accept button offered).
    expect(find.text('No clear cause'), findsOneWidget);
    expect(find.textContaining('Nothing in the pump or CGM history around'),
        findsOneWidget);
  });

  testWidgets(
      'tagging ignore via the bottom sheet updates eventDispositionProvider '
      'with the chosen reason', (tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(_host(Builder(builder: (context) {
      hostContext = context;
      return TimelineEventCard(event: _event(type: DayEventType.high));
    })));

    await tester.tap(find.text('Use for model'));
    await tester.pumpAndSettle();

    // DayEventType.high offers siteFailure/illness/missedCarbs/other reasons.
    expect(find.textContaining('Ignore — Illness'), findsOneWidget);
    await tester.tap(find.textContaining('Ignore — Illness'));
    await tester.pumpAndSettle();

    final overrides =
        ProviderScope.containerOf(hostContext, listen: false)
            .read(eventDispositionProvider);
    expect(overrides['e1']?.disposition, ModelDisposition.ignore);
    expect(overrides['e1']?.reason, IgnoreReason.illness);
  });

  testWidgets('tapping "Use for model" in the sheet marks the event in-use',
      (tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(_host(Builder(builder: (context) {
      hostContext = context;
      return TimelineEventCard(
        event: _event(
          disposition: ModelDisposition.ignore,
          ignoreReason: IgnoreReason.compressionLow,
        ),
      );
    })));

    await tester.tap(find.text('Ignored'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use for model').last);
    await tester.pumpAndSettle();

    final overrides =
        ProviderScope.containerOf(hostContext, listen: false)
            .read(eventDispositionProvider);
    expect(overrides['e1']?.disposition, ModelDisposition.use);
    expect(overrides['e1']?.reason, isNull);
  });
}
