/// DST-safe local day boundaries (issue #108).
///
/// **Why this test uses the `timezone` package.** The production helpers use local
/// `DateTime`, and this machine is Brisbane (UTC+10, no DST) while CI runs in UTC — on
/// both, `+Duration(days: 1)` and calendar arithmetic agree, so a plain-`DateTime` test
/// would pass whether or not the bug exists. Constructing the transition explicitly in a
/// DST-observing zone is the only way to actually check the property.
library;

import 'package:bgdude/core/local_day.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('the DST hazard this exists to prevent', () {
    late tz.Location sydney;

    setUp(() => sydney = tz.getLocation('Australia/Sydney'));

    test('a fall-back day is 25 hours, so +24h drops its last hour', () {
      // 2026-04-05: Sydney puts clocks BACK at 03:00.
      final dayStart = tz.TZDateTime(sydney, 2026, 4, 5);
      final nextMidnight = tz.TZDateTime(sydney, 2026, 4, 6);

      expect(nextMidnight.difference(dayStart), const Duration(hours: 25));

      final plus24 = dayStart.add(const Duration(hours: 24));
      expect(plus24.hour, 23,
          reason: '+24h lands at 23:00, an hour short of midnight');
      expect(plus24.isBefore(nextMidnight), isTrue,
          reason: 'the last hour of the day would be excluded');
    });

    test('a spring-forward day is 23 hours, so +24h overshoots into the next',
        () {
      // 2026-10-04: Sydney puts clocks FORWARD at 02:00.
      final dayStart = tz.TZDateTime(sydney, 2026, 10, 4);
      final nextMidnight = tz.TZDateTime(sydney, 2026, 10, 5);

      expect(nextMidnight.difference(dayStart), const Duration(hours: 23));

      final plus24 = dayStart.add(const Duration(hours: 24));
      expect(plus24.day, 5);
      expect(plus24.hour, 1,
          reason: '+24h lands at 01:00 the NEXT day, swallowing an hour of it');
    });

    test('calendar arithmetic lands on midnight through both transitions', () {
      // The property the production helpers rely on, shown in the zone where it
      // actually differs.
      for (final d in [
        tz.TZDateTime(sydney, 2026, 4, 5),
        tz.TZDateTime(sydney, 2026, 10, 4),
      ]) {
        final next = tz.TZDateTime(sydney, d.year, d.month, d.day + 1);
        expect(next.hour, 0, reason: '$d');
        expect(next.day, d.day + 1, reason: '$d');
      }
    });
  });

  group('local day helpers', () {
    test('a window starts and ends at midnight', () {
      final w = localDayWindow(DateTime(2026, 7, 4, 13, 37));

      expect(w.start, DateTime(2026, 7, 4));
      expect(w.end, DateTime(2026, 7, 5));
      expect(w.start.hour, 0);
      expect(w.end.hour, 0);
    });

    test('month and year rollover', () {
      expect(endOfLocalDay(DateTime(2026, 1, 31)), DateTime(2026, 2, 1));
      expect(endOfLocalDay(DateTime(2026, 12, 31)), DateTime(2027, 1, 1));
      expect(addLocalDays(DateTime(2026, 12, 30), 5), DateTime(2027, 1, 4));
    });

    test('a leap day is handled', () {
      expect(endOfLocalDay(DateTime(2028, 2, 28)), DateTime(2028, 2, 29));
      expect(endOfLocalDay(DateTime(2028, 2, 29)), DateTime(2028, 3, 1));
    });

    test('addLocalDays(0) is the start of the same day', () {
      expect(addLocalDays(DateTime(2026, 7, 4, 23, 59), 0), DateTime(2026, 7, 4));
    });

    test('the window is half-open at midnight', () {
      // A reading at exactly midnight belongs to the day starting then. Without
      // this it is counted in both days.
      final day = DateTime(2026, 7, 4);

      expect(isSameLocalDay(DateTime(2026, 7, 4), day), isTrue);
      expect(isSameLocalDay(DateTime(2026, 7, 4, 23, 59, 59), day), isTrue);
      expect(isSameLocalDay(DateTime(2026, 7, 5), day), isFalse,
          reason: 'the next midnight belongs to the next day');
      expect(isSameLocalDay(DateTime(2026, 7, 3, 23, 59, 59), day), isFalse);
    });

    test('startOfLocalDay is idempotent', () {
      final s = startOfLocalDay(DateTime(2026, 7, 4, 9));
      expect(startOfLocalDay(s), s);
    });
  });
}
