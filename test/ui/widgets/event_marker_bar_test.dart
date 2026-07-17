import 'package:bgdude/timeline/day_event.dart';
import 'package:bgdude/ui/widgets/event_marker_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DayEvent _event(String id, DateTime time,
        {bool explainable = true, DayEventType type = DayEventType.high}) =>
    DayEvent(
      id: id,
      type: type,
      time: time,
      title: 'title-$id',
      detail: 'detail-$id',
      explainable: explainable,
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
          body:
              SizedBox(width: 300, child: SizedBox(height: 40, child: child))),
    );

void main() {
  final now = DateTime(2026, 7, 10, 9, 0);

  testWidgets('renders a marker per explainable event, skips non-explainable',
      (tester) async {
    final events = [
      _event('a', now.subtract(const Duration(minutes: 30))),
      _event('b', now.subtract(const Duration(minutes: 10)),
          explainable: false),
      _event('c', now),
    ];
    await tester.pumpWidget(_host(EventMarkerBar(
      events: events,
      minX: -60,
      maxX: 60,
      xForTime: (t) => t.difference(now).inMinutes.toDouble(),
      onTap: (_) {},
    )));

    expect(find.byKey(const ValueKey('event-marker-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('event-marker-b')), findsNothing);
    expect(find.byKey(const ValueKey('event-marker-c')), findsOneWidget);
  });

  testWidgets('events outside the x-domain are not rendered', (tester) async {
    final events = [
      _event('in', now),
      _event('out', now.subtract(const Duration(hours: 5))),
    ];
    await tester.pumpWidget(_host(EventMarkerBar(
      events: events,
      minX: -60,
      maxX: 60,
      xForTime: (t) => t.difference(now).inMinutes.toDouble(),
      onTap: (_) {},
    )));

    expect(find.byKey(const ValueKey('event-marker-in')), findsOneWidget);
    expect(find.byKey(const ValueKey('event-marker-out')), findsNothing);
  });

  testWidgets('tapping a marker invokes onTap with that event', (tester) async {
    DayEvent? tapped;
    final events = [_event('a', now)];
    await tester.pumpWidget(_host(EventMarkerBar(
      events: events,
      minX: -60,
      maxX: 60,
      xForTime: (t) => t.difference(now).inMinutes.toDouble(),
      onTap: (e) => tapped = e,
    )));

    await tester.tap(find.byKey(const ValueKey('event-marker-a')));
    await tester.pump();

    expect(tapped?.id, 'a');
  });

  testWidgets('an empty event list renders without error', (tester) async {
    await tester.pumpWidget(_host(EventMarkerBar(
      events: const [],
      minX: -60,
      maxX: 60,
      xForTime: (t) => t.difference(now).inMinutes.toDouble(),
      onTap: (_) {},
    )));

    expect(tester.takeException(), isNull);
    expect(find.byType(EventMarkerBar), findsOneWidget);
  });
}
