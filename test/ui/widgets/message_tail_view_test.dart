/// The pump message tail's rendering (issue #92).
library;

import 'package:bgdude/pump/probe_event.dart';
import 'package:bgdude/ui/widgets/message_tail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProbeEvent _event(String name, {int? opcode, String? cargo, String dir = 'rx'}) =>
    ProbeEvent(
      direction: dir,
      name: name,
      timestampMs: 0,
      opcode: opcode,
      cargoHex: cargo,
    );

Future<void> _pump(
  WidgetTester tester, {
  List<ProbeEvent> events = const [],
  int dropped = 0,
  bool capturing = true,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MessageTailView(
        events: events,
        dropped: dropped,
        capturing: capturing,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the message and its bytes', (tester) async {
    await _pump(tester,
        events: [_event('ControlIQSleepSchedule', opcode: 107, cargo: '017f')]);

    expect(find.text('← ControlIQSleepSchedule op 107'), findsOneWidget);
    expect(find.text('017f'), findsOneWidget);
  });

  testWidgets('a dropped count is stated, not hidden', (tester) async {
    // A tail that silently discarded its own beginning lies about when a problem
    // started.
    await _pump(tester, events: [_event('A')], dropped: 42);

    expect(find.textContaining('42 older messages dropped'), findsOneWidget);
  });

  testWidgets('no dropped notice when nothing was dropped', (tester) async {
    await _pump(tester, events: [_event('A')]);

    expect(find.textContaining('dropped'), findsNothing);
  });

  testWidgets('the dropped notice is singular for one', (tester) async {
    await _pump(tester, events: [_event('A')], dropped: 1);

    expect(find.textContaining('1 older message dropped'), findsOneWidget);
  });

  testWidgets('an empty tail distinguishes "nothing yet" from "not capturing"',
      (tester) async {
    // Otherwise a monitor that is simply switched off looks like a pump that has
    // gone quiet — a much more alarming conclusion.
    await _pump(tester);
    expect(find.textContaining('Nothing yet'), findsOneWidget);

    await _pump(tester, capturing: false);
    expect(find.textContaining('Capture is off'), findsOneWidget);
  });

  testWidgets('a sent message points the other way', (tester) async {
    await _pump(tester, events: [_event('Request', dir: 'tx')]);

    expect(find.text('→ Request'), findsOneWidget);
  });
}
