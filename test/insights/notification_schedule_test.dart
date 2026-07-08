/// TASK-175: scheduled notifications must fire at the LOCAL wall-clock time.
/// These tests pin the schedule computation under a non-UTC location (Sydney,
/// UTC+10/+11) — before the fix `tz.local` stayed UTC, so the 07:00 morning
/// summary fired at 17:00 AEST.
library;

import 'package:bgdude/insights/notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tzdata.initializeTimeZones();
  final sydney = tz.getLocation('Australia/Sydney');

  group('nextDailyInstant', () {
    test('07:00 Sydney is 21:00 UTC in winter (AEST, UTC+10)', () {
      final now = tz.TZDateTime(sydney, 2026, 7, 7, 8); // past 07:00 → tomorrow
      final at = NotificationService.nextDailyInstant(now, 7, 0);
      expect(at.hour, 7);
      expect(at.day, 8);
      final utc = at.toUtc();
      expect(utc.hour, 21);
      expect(utc.day, 7);
    });

    test('same day when the slot is still ahead', () {
      final now = tz.TZDateTime(sydney, 2026, 7, 7, 5, 30);
      final at = NotificationService.nextDailyInstant(now, 7, 0);
      expect(at.day, 7);
      expect(at.hour, 7);
    });

    test('keeps the wall-clock hour across the DST spring-forward', () {
      // Sydney DST starts 2026-10-04 02:00 (+10 → +11). Scheduling from the
      // evening before must land on 07:00 AEDT — 20:00 UTC, not 21:00.
      final now = tz.TZDateTime(sydney, 2026, 10, 3, 20);
      final at = NotificationService.nextDailyInstant(now, 7, 0);
      expect(at.hour, 7);
      expect(at.day, 4);
      expect(at.toUtc().hour, 20);
    });

    test('keeps the wall-clock hour across the DST fall-back', () {
      // Sydney DST ends 2026-04-05 03:00 (+11 → +10).
      final now = tz.TZDateTime(sydney, 2026, 4, 4, 22);
      final at = NotificationService.nextDailyInstant(now, 7, 0);
      expect(at.hour, 7);
      expect(at.day, 5);
      expect(at.toUtc().hour, 21); // back on +10
    });
  });

  group('nextWeeklyInstant', () {
    test('lands on the requested weekday at the local hour', () {
      final now = tz.TZDateTime(sydney, 2026, 7, 7, 12); // a Tuesday
      final at =
          NotificationService.nextWeeklyInstant(now, DateTime.monday, 8);
      expect(at.weekday, DateTime.monday);
      expect(at.hour, 8);
      expect(at.isAfter(now), isTrue);
      expect(at.difference(now).inDays, lessThan(7));
    });

    test('a slot earlier today rolls a full week', () {
      final now = tz.TZDateTime(sydney, 2026, 7, 6, 9); // Monday 09:00
      final at =
          NotificationService.nextWeeklyInstant(now, DateTime.monday, 8);
      expect(at.weekday, DateTime.monday);
      expect(at.day, 13);
    });
  });

  group('schedule modes per path (TASK-182)', () {
    test('the pre-bolus timer is EXACT when permitted, inexact otherwise', () {
      expect(NotificationService.preBolusScheduleMode(canExact: true),
          AndroidScheduleMode.exactAllowWhileIdle);
      expect(NotificationService.preBolusScheduleMode(canExact: false),
          AndroidScheduleMode.inexactAllowWhileIdle);
    });

    test('summaries and nudges stay inexact (Doze slack is fine there)', () {
      expect(NotificationService.summaryScheduleMode,
          AndroidScheduleMode.inexactAllowWhileIdle);
    });
  });
}
