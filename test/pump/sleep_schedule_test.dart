/// Control-IQ sleep-window projection (issue #87).
library;

import 'package:bgdude/pump/sleep_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real captured schedule: every day, 22:00 -> 07:00 (doc/pump-protocol.md).
const _captured = SleepSchedule(
  daysBitmask: 0x7f,
  startMinute: 1320,
  endMinute: 420,
);

void main() {
  group('tryParse', () {
    test('parses the native encoding', () {
      final s = SleepSchedule.tryParse('127:1320:420')!;
      expect(s.daysBitmask, 0x7f);
      expect(s.startMinute, 1320);
      expect(s.label, '22:00–07:00');
      expect(s.wrapsMidnight, isTrue);
    });

    test('malformed slots are dropped, not thrown', () {
      // A garbled slot must not take down the whole chart.
      for (final bad in ['', 'x:1:2', '1:2', '127:1320:420:9', '0:1320:420',
        '127:-5:420', '127:1320:1440']) {
        expect(SleepSchedule.tryParse(bad), isNull, reason: bad);
      }
    });
  });

  group('sleepWindowsInRange', () {
    test('the half of an overnight window before now is still shaded', () {
      // 02:00 Wednesday: the window began at 22:00 TUESDAY. Testing only today's
      // weekday would drop it, leaving the trace flat with no explanation.
      final now = DateTime(2026, 7, 15, 2);
      final w = sleepWindowsInRange([_captured], now, -150, 240);

      expect(w, hasLength(1));
      // Clipped to the chart's left edge; it really started 240 min ago.
      expect(w.single.startMinutesFromNow, -150);
      // Ends 07:00 — five hours out, so clipped to the chart's right edge.
      expect(w.single.endMinutesFromNow, 240);
    });

    test('a window starting later tonight is shaded ahead of now', () {
      final now = DateTime(2026, 7, 15, 20); // 20:00, sleep starts 22:00
      final w = sleepWindowsInRange([_captured], now, -150, 240);

      expect(w, hasLength(1));
      expect(w.single.startMinutesFromNow, 120);
      expect(w.single.endMinutesFromNow, 240); // clipped at the chart's right edge
    });

    test('midday shows nothing', () {
      final w = sleepWindowsInRange([_captured], DateTime(2026, 7, 15, 12), -150, 240);
      expect(w, isEmpty);
    });

    test('a weekday-only schedule does not shade the weekend', () {
      // Mon-Fri (0x1f). Saturday 02:00 is outside it, but FRIDAY 22:00 -> Saturday
      // 07:00 IS in it, so Saturday morning must still shade; Sunday morning must not.
      const weekdays = SleepSchedule(
        daysBitmask: 0x1f,
        startMinute: 1320,
        endMinute: 420,
      );
      expect(DateTime(2026, 7, 18).weekday, DateTime.saturday);

      final sat = sleepWindowsInRange([weekdays], DateTime(2026, 7, 18, 2), -150, 240);
      expect(sat, hasLength(1), reason: 'Friday night runs into Saturday morning');

      // Saturday night 23:00 is NOT a Mon-Fri start, so Sunday morning is unshaded.
      final sun = sleepWindowsInRange([weekdays], DateTime(2026, 7, 19, 2), -150, 240);
      expect(sun, isEmpty);
    });

    test('a non-wrapping daytime window is handled too', () {
      const nap = SleepSchedule(daysBitmask: 0x7f, startMinute: 780, endMinute: 900);
      expect(nap.wrapsMidnight, isFalse);
      final w = sleepWindowsInRange([nap], DateTime(2026, 7, 15, 13, 30), -150, 240);
      expect(w.single.startMinutesFromNow, -30);
      expect(w.single.endMinutesFromNow, 90);
    });

    test('multiple slots come back in chronological order', () {
      const a = SleepSchedule(daysBitmask: 0x7f, startMinute: 1320, endMinute: 420);
      const b = SleepSchedule(daysBitmask: 0x7f, startMinute: 780, endMinute: 900);
      final w = sleepWindowsInRange([a, b], DateTime(2026, 7, 15, 12), -150, 720);
      expect(w.map((e) => e.startMinutesFromNow), [60, 600]);
    });

    test('no schedules means no shading', () {
      expect(sleepWindowsInRange([], DateTime(2026, 7, 15, 2), -150, 240), isEmpty);
    });
  });
}
