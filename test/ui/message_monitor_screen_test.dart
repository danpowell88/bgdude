/// The message monitor screen (issue #92).
library;

import 'package:bgdude/pump/message_ring_buffer.dart';
import 'package:bgdude/pump/probe_event.dart';
import 'package:bgdude/ui/message_monitor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProbeEvent _e(String name, {String dir = 'rx', int? opcode, String? cargo}) =>
    ProbeEvent(
      direction: dir,
      name: name,
      timestampMs: 0,
      opcode: opcode,
      cargoHex: cargo,
    );

MessageRingBuffer _buffer({int capacity = 500}) {
  final b = MessageRingBuffer(capacity: capacity);
  b.add(_e('CurrentBasalStatus', opcode: 40, cargo: 'aabb'));
  b.add(_e('SendProbe', dir: 'tx', opcode: 41));
  b.add(_e('ControlIQSleepSchedule', opcode: 107, cargo: '017f2805'));
  return b;
}

Future<void> _pump(WidgetTester tester, MessageRingBuffer buffer) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(home: MessageMonitorScreen(bufferOverride: buffer)),
  ));
  await tester.pump();
}

void main() {
  testWidgets('lists the tail newest-first with a count', (tester) async {
    await _pump(tester, _buffer());

    expect(find.text('← ControlIQSleepSchedule op 107'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('filters by name', (tester) async {
    await _pump(tester, _buffer());

    await tester.enterText(
        find.byKey(const Key('message-monitor-filter')), 'sleep');
    await tester.pump();

    expect(find.text('← ControlIQSleepSchedule op 107'), findsOneWidget);
    expect(find.text('← CurrentBasalStatus op 40'), findsNothing);
  });

  testWidgets('filters by opcode and by cargo bytes', (tester) async {
    await _pump(tester, _buffer());

    await tester.enterText(
        find.byKey(const Key('message-monitor-filter')), '7f28');
    await tester.pump();
    expect(find.text('← ControlIQSleepSchedule op 107'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('message-monitor-filter')), '40');
    await tester.pump();
    expect(find.text('← CurrentBasalStatus op 40'), findsOneWidget);
  });

  testWidgets('the direction chips narrow the tail', (tester) async {
    await _pump(tester, _buffer());

    await tester.tap(find.text('Sent'));
    await tester.pump();

    expect(find.text('→ SendProbe op 41'), findsOneWidget);
    expect(find.text('← CurrentBasalStatus op 40'), findsNothing);

    await tester.tap(find.text('Received'));
    await tester.pump();
    expect(find.text('→ SendProbe op 41'), findsNothing);
  });

  testWidgets('clear empties the tail', (tester) async {
    final buffer = _buffer();
    await _pump(tester, buffer);

    await tester.tap(find.byKey(const Key('message-monitor-clear')));
    await tester.pump();

    expect(buffer.isEmpty, isTrue);
    expect(find.textContaining('Nothing yet'), findsOneWidget);
  });

  testWidgets('a truncated tail says how much it dropped', (tester) async {
    // Silent truncation would make the monitor lie about when a problem started.
    final buffer = MessageRingBuffer(capacity: 2);
    for (var i = 0; i < 5; i++) {
      buffer.add(_e('M$i'));
    }

    await _pump(tester, buffer);

    expect(find.textContaining('3 older messages dropped'), findsOneWidget);
  });
}
