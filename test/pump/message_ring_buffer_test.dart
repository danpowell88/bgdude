/// The always-on pump message tail (issue #92).
library;

import 'package:bgdude/pump/message_ring_buffer.dart';
import 'package:bgdude/pump/probe_event.dart';
import 'package:flutter_test/flutter_test.dart';

ProbeEvent _event(
  String name, {
  String direction = 'rx',
  int? opcode,
  String? cargo,
  int ts = 0,
}) =>
    ProbeEvent(
      direction: direction,
      name: name,
      timestampMs: ts,
      opcode: opcode,
      cargoHex: cargo,
    );

void main() {
  group('MessageRingBuffer', () {
    test('keeps events oldest-first and exposes a newest-first tail', () {
      final buffer = MessageRingBuffer()
        ..add(_event('First'))
        ..add(_event('Second'));

      expect(buffer.events.map((e) => e.name), ['First', 'Second']);
      expect(buffer.newestFirst.map((e) => e.name), ['Second', 'First']);
    });

    test('drops the oldest once capacity is reached', () {
      // An unbounded buffer on a chatty BLE link is a slow leak that only bites on
      // the long connections that matter most.
      final buffer = MessageRingBuffer(capacity: 3);
      for (var i = 0; i < 5; i++) {
        buffer.add(_event('M$i'));
      }

      expect(buffer.length, 3);
      expect(buffer.events.map((e) => e.name), ['M2', 'M3', 'M4']);
    });

    test('reports how many it dropped', () {
      // Silent truncation makes a tail lie about when a problem started.
      final buffer = MessageRingBuffer(capacity: 2);
      for (var i = 0; i < 6; i++) {
        buffer.add(_event('M$i'));
      }

      expect(buffer.dropped, 4);
    });

    test('nothing is dropped while under capacity', () {
      final buffer = MessageRingBuffer(capacity: 10)..add(_event('One'));
      expect(buffer.dropped, 0);
    });

    test('clear empties the buffer and the drop count', () {
      final buffer = MessageRingBuffer(capacity: 1)
        ..add(_event('A'))
        ..add(_event('B'));
      expect(buffer.dropped, 1);

      buffer.clear();

      expect(buffer.isEmpty, isTrue);
      expect(buffer.dropped, 0, reason: 'a cleared tail has dropped nothing');
    });

    test('a zero capacity is rejected rather than silently recording nothing', () {
      expect(() => MessageRingBuffer(capacity: 0), throwsA(isA<AssertionError>()));
    });

    test('the exposed list cannot be mutated by a caller', () {
      final buffer = MessageRingBuffer()..add(_event('A'));
      expect(() => buffer.events.add(_event('B')), throwsUnsupportedError);
    });
  });

  group('filterEvents', () {
    final events = [
      _event('CurrentBasalStatus', opcode: 40, cargo: 'aabb'),
      _event('SendRequest', direction: 'tx', opcode: 41, cargo: 'ccdd'),
      _event('ControlIQSleepSchedule', opcode: 107, cargo: '017f2805'),
    ];

    test('an empty query keeps everything', () {
      expect(filterEvents(events), hasLength(3));
    });

    test('matches on message name, case-insensitively', () {
      expect(filterEvents(events, query: 'sleep').single.opcode, 107);
      expect(filterEvents(events, query: 'SLEEP').single.opcode, 107);
    });

    test('matches on opcode', () {
      // "opcode 107" is one of the three things you actually search for.
      expect(filterEvents(events, query: '107').single.name,
          'ControlIQSleepSchedule');
    });

    test('matches on cargo bytes', () {
      // Finding the response that contained particular bytes is the whole point of
      // having the hex.
      expect(filterEvents(events, query: '7f28').single.opcode, 107);
    });

    test('filters by direction', () {
      expect(filterEvents(events, direction: 'tx').single.name, 'SendRequest');
      expect(filterEvents(events, direction: 'rx'), hasLength(2));
    });

    test('direction and query combine', () {
      expect(filterEvents(events, direction: 'rx', query: '41'), isEmpty,
          reason: 'opcode 41 is the tx one');
    });

    test('an event with no opcode or cargo does not crash the filter', () {
      expect(filterEvents([_event('Bare')], query: 'zzz'), isEmpty);
      expect(filterEvents([_event('Bare')], query: 'bare'), hasLength(1));
    });
  });

  group('describeEvent', () {
    test('shows direction and opcode at a glance', () {
      expect(describeEvent(_event('Resp', opcode: 107)), '← Resp op 107');
      expect(describeEvent(_event('Req', direction: 'tx')), '→ Req');
    });
  });
}
