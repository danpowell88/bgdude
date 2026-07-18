/// Alarm-fatigue rollup and suggestion (issue #171).
///
/// Every case pins a fixed `now`, so nothing here depends on when the suite runs —
/// the failure mode #383 cost a session to diagnose.
library;

import 'package:bgdude/insights/alarm_fatigue.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 19, 12);

AlertEvent _at(Duration ago, NotificationCategory c) =>
    AlertEvent(category: c, firedAt: _now.subtract(ago));

/// n events of [c] spread an hour apart inside this week, at [hour] local.
List<AlertEvent> _burst(int n, NotificationCategory c, {int hour = 12}) => [
      for (var i = 0; i < n; i++)
        AlertEvent(
          category: c,
          firedAt: DateTime(2026, 7, 18, hour).subtract(Duration(minutes: i)),
        ),
    ];

void main() {
  group('rollupWeek', () {
    test('counts only the last 7 days, and the 7 before that separately', () {
      final events = [
        _at(const Duration(days: 1), NotificationCategory.predictedLow),
        _at(const Duration(days: 6), NotificationCategory.predictedLow),
        // Prior week.
        _at(const Duration(days: 8), NotificationCategory.predictedHigh),
        _at(const Duration(days: 13), NotificationCategory.predictedHigh),
        // Older than both windows — must be ignored entirely, so a caller can pass
        // a wider query result without pre-filtering.
        _at(const Duration(days: 40), NotificationCategory.urgentLow),
      ];

      final r = rollupWeek(events, _now);

      expect(r.total, 2);
      expect(r.previousTotal, 2);
      expect(r.weekOverWeekDelta, 0);
    });

    test('a boundary event counts once, in this week only', () {
      // Exactly on the 7-day edge. Counting it in both windows would inflate this
      // week AND last week, making the delta wrong in both directions at once.
      final r = rollupWeek(
          [_at(const Duration(days: 7), NotificationCategory.predictedLow)], _now);

      expect(r.total, 1);
      expect(r.previousTotal, 0);
    });

    test('per-category counts are ordered highest first', () {
      final r = rollupWeek([
        ..._burst(2, NotificationCategory.predictedHigh),
        ..._burst(5, NotificationCategory.predictedLow),
        ..._burst(1, NotificationCategory.missedBolus),
      ], _now);

      expect(r.perCategory.keys.toList(), [
        NotificationCategory.predictedLow,
        NotificationCategory.predictedHigh,
        NotificationCategory.missedBolus,
      ]);
      expect(r.perCategory[NotificationCategory.predictedLow], 5);
    });

    test('overnight share uses 22:00-07:00 and is 0 (not NaN) on an empty week', () {
      final overnight = rollupWeek([
        ..._burst(3, NotificationCategory.predictedLow, hour: 23),
        ..._burst(1, NotificationCategory.predictedLow, hour: 3),
        ..._burst(4, NotificationCategory.predictedLow, hour: 13),
      ], _now);
      expect(overnight.overnightShare, closeTo(0.5, 1e-9));

      // NaN here would propagate into any percentage the UI formats.
      final empty = rollupWeek(const [], _now);
      expect(empty.overnightShare, 0);
      expect(empty.total, 0);
    });

    test('22:00 is overnight and 07:00 is not — the edges themselves', () {
      expect(AlarmFatigueRollup.isOvernight(DateTime(2026, 7, 18, 22)), isTrue);
      expect(AlarmFatigueRollup.isOvernight(DateTime(2026, 7, 18, 21, 59)), isFalse);
      expect(AlarmFatigueRollup.isOvernight(DateTime(2026, 7, 18, 6, 59)), isTrue);
      expect(AlarmFatigueRollup.isOvernight(DateTime(2026, 7, 18, 7)), isFalse);
    });

    test('week-over-week delta is positive when alerting got noisier', () {
      final r = rollupWeek([
        ..._burst(9, NotificationCategory.predictedLow),
        _at(const Duration(days: 9), NotificationCategory.predictedLow),
      ], _now);

      expect(r.total, 9);
      expect(r.previousTotal, 1);
      expect(r.weekOverWeekDelta, 8);
    });
  });

  group('dominantCategory / suggestion', () {
    test('a lopsided week names the dominant category', () {
      final r = rollupWeek([
        ..._burst(8, NotificationCategory.predictedLow),
        ..._burst(2, NotificationCategory.predictedHigh),
      ], _now);

      expect(r.dominantCategory, NotificationCategory.predictedLow);
      final s = alarmFatigueSuggestion(r);
      expect(s, isNotNull);
      // It has to name the category — "you got a lot of alerts" is something the
      // user already knows and can't act on.
      expect(s, contains('Low predicted'));
      expect(s, contains('80%'));
    });

    test('an evenly spread week suggests nothing', () {
      final r = rollupWeek([
        ..._burst(4, NotificationCategory.predictedLow),
        ..._burst(4, NotificationCategory.predictedHigh),
      ], _now);

      // 50% is the largest, but not lopsided — tuning on it would be guesswork.
      expect(r.dominantCategory, isNull);
      expect(alarmFatigueSuggestion(r), isNull);
    });

    test('a quiet week suggests nothing even at 100% concentration', () {
      // 3 alerts all of one kind is arithmetic, not a finding. Without the volume
      // floor this would confidently tell the user to retune on three data points.
      final r =
          rollupWeek(_burst(3, NotificationCategory.predictedLow), _now);

      expect(r.total, 3);
      expect(r.perCategory[NotificationCategory.predictedLow], 3);
      expect(r.dominantCategory, isNull,
          reason: 'below the ${AlarmFatigueRollup.minimumForSuggestion}-event floor');
    });

    test('a mostly-overnight dominant category says so, and points at the fix', () {
      final r = rollupWeek(_burst(10, NotificationCategory.predictedLow, hour: 2), _now);

      final s = alarmFatigueSuggestion(r);
      expect(s, contains('overnight'));
      // The actionable half: which knob to turn.
      expect(s, contains('threshold or repeat interval'));
    });
  });
}
