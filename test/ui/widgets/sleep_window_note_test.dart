/// The Control-IQ sleep explanation (issue #87).
library;

import 'package:bgdude/pump/sleep_schedule.dart';
import 'package:bgdude/ui/widgets/sleep_window_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _captured = SleepSchedule(
  daysBitmask: 0x7f,
  startMinute: 1320,
  endMinute: 420,
);

Future<void> _pump(
  WidgetTester tester,
  List<SleepSchedule> schedules,
  DateTime now,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SleepWindowNote(schedules: schedules, now: now)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('inside the window it says so in the present tense',
      (tester) async {
    await _pump(tester, [_captured], DateTime(2026, 7, 15, 2));

    expect(find.textContaining('in sleep mode now'), findsOneWidget);
    expect(find.textContaining('22:00–07:00'), findsOneWidget);
    // The actual reason the trace looks different.
    expect(find.textContaining('tighter target'), findsOneWidget);
  });

  testWidgets('outside the window it describes when sleep runs', (tester) async {
    await _pump(tester, [_captured], DateTime(2026, 7, 15, 12));

    expect(find.textContaining('in sleep mode now'), findsNothing);
    expect(find.textContaining('sleep runs 22:00–07:00'), findsOneWidget);
  });

  testWidgets('renders nothing when the pump has told us nothing',
      (tester) async {
    // An empty list covers both "not read yet" and "sleep is off"; claiming
    // "Control-IQ never sleeps" from that would overstate what we know.
    await _pump(tester, const [], DateTime(2026, 7, 15, 2));

    expect(find.byType(Card), findsNothing);
  });

  test('isAsleepAt is true only inside the window', () {
    expect(SleepWindowNote.isAsleepAt([_captured], DateTime(2026, 7, 15, 2)), isTrue);
    expect(SleepWindowNote.isAsleepAt([_captured], DateTime(2026, 7, 15, 23)), isTrue);
    expect(SleepWindowNote.isAsleepAt([_captured], DateTime(2026, 7, 15, 12)), isFalse);
    // Boundaries: 07:00 is the end, 21:59 is a minute short of the start.
    expect(SleepWindowNote.isAsleepAt([_captured], DateTime(2026, 7, 15, 21, 59)), isFalse);
  });
}
