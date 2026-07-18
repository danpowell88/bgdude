/// Alarm-fatigue analytics over recorded alert history (issue #171).
///
/// Alarm fatigue is the top reason people abandon alerting, and it can't be tuned
/// without measuring it — `AlertService`'s cooldown gate is in-memory only, so before
/// this nothing recorded which alerts actually fired.
///
/// Pure functions over a list of events: no clock, no database, no Riverpod. The
/// caller supplies `now` and the rows, which is what makes every threshold here
/// testable at a fixed instant.
library;

import 'notification_prefs.dart';

/// One recorded firing.
class AlertEvent {
  const AlertEvent({required this.category, required this.firedAt});

  final NotificationCategory category;
  final DateTime firedAt;
}

/// A week's alert activity, plus the change from the week before.
class AlarmFatigueRollup {
  const AlarmFatigueRollup({
    required this.total,
    required this.perCategory,
    required this.overnightShare,
    required this.previousTotal,
  });

  final int total;

  /// Counts per category, highest first — insertion-ordered so callers can render
  /// it directly without re-sorting.
  final Map<NotificationCategory, int> perCategory;

  /// Fraction of this week's alerts that fired overnight (0.0–1.0), where overnight
  /// is 22:00–07:00 local. 0 when there were no alerts — not NaN, which would
  /// propagate into any percentage the UI formats.
  final double overnightShare;

  final int previousTotal;

  /// This week minus last week. Positive means alerting got noisier.
  int get weekOverWeekDelta => total - previousTotal;

  /// The category responsible for [dominantShareThreshold] or more of the week's
  /// alerts, when there is one and the week has enough volume to mean anything.
  ///
  /// Null below [minimumForSuggestion] events: with three alerts in a week, "100% of
  /// your alerts are predicted lows" is arithmetic, not a finding, and acting on it
  /// would be tuning against noise.
  NotificationCategory? get dominantCategory {
    if (total < minimumForSuggestion) return null;
    for (final entry in perCategory.entries) {
      if (entry.value / total >= dominantShareThreshold) return entry.key;
    }
    return null;
  }

  /// Deliberately > 50%, so "dominant" means genuinely lopsided rather than merely
  /// the largest of several.
  static const double dominantShareThreshold = 0.6;

  /// Below this a week's distribution is noise; chosen so roughly one alert a day is
  /// the floor for drawing any conclusion.
  static const int minimumForSuggestion = 7;

  /// Overnight window, inclusive of 22:00, exclusive of 07:00.
  static const int overnightStartHour = 22;
  static const int overnightEndHour = 7;

  static bool isOvernight(DateTime t) =>
      t.hour >= overnightStartHour || t.hour < overnightEndHour;
}

/// Roll [events] up for the seven days ending at [now], comparing with the seven
/// before that. Events outside both windows are ignored, so the caller can pass a
/// wider query result without pre-filtering.
AlarmFatigueRollup rollupWeek(List<AlertEvent> events, DateTime now) {
  final weekStart = now.subtract(const Duration(days: 7));
  final priorStart = now.subtract(const Duration(days: 14));

  final thisWeek = <AlertEvent>[];
  var previousTotal = 0;
  for (final e in events) {
    // Half-open windows: an event exactly on weekStart belongs to this week only, so
    // a boundary event can't be counted in both and inflate the delta.
    if (!e.firedAt.isBefore(weekStart) && !e.firedAt.isAfter(now)) {
      thisWeek.add(e);
    } else if (!e.firedAt.isBefore(priorStart) && e.firedAt.isBefore(weekStart)) {
      previousTotal++;
    }
  }

  final counts = <NotificationCategory, int>{};
  var overnight = 0;
  for (final e in thisWeek) {
    counts[e.category] = (counts[e.category] ?? 0) + 1;
    if (AlarmFatigueRollup.isOvernight(e.firedAt)) overnight++;
  }

  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return AlarmFatigueRollup(
    total: thisWeek.length,
    perCategory: {for (final e in sorted) e.key: e.value},
    overnightShare: thisWeek.isEmpty ? 0 : overnight / thisWeek.length,
    previousTotal: previousTotal,
  );
}

/// A one-line, actionable suggestion, or null when the week says nothing useful.
///
/// Says what to change, not just what happened — "you got a lot of alerts" is an
/// observation the user already has; naming the category and pointing at its
/// threshold is the part they can act on.
String? alarmFatigueSuggestion(AlarmFatigueRollup rollup) {
  final dominant = rollup.dominantCategory;
  if (dominant == null) return null;
  final share = (rollup.perCategory[dominant]! / rollup.total * 100).round();
  final overnight = (rollup.overnightShare * 100).round();
  final overnightNote = rollup.overnightShare >= 0.5
      ? ' Most of them fired overnight, so its threshold or repeat interval is the '
          'one worth revisiting first.'
      : '';
  return '$share% of this week\'s ${rollup.total} alerts were '
      '"${dominant.label}"$overnightNote'
      '${overnightNote.isEmpty ? ' ($overnight% overnight).' : ''}';
}
