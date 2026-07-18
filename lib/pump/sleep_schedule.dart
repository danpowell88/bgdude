/// Control-IQ's sleep schedule (issue #87), read from the pump.
///
/// During a sleep window Control-IQ aims at a tighter overnight target band than it
/// does by day, which is why overnight traces often look flatter and why a correction
/// can behave differently at 02:00 than at 14:00. bgdude only reads this — sleep
/// schedules are edited on the pump (decision-1).
library;

/// One enabled sleep slot: which weekdays it applies to, and the local start/end
/// minute-of-day. A window whose end is <= its start runs past midnight.
class SleepSchedule {
  const SleepSchedule({
    required this.daysBitmask,
    required this.startMinute,
    required this.endMinute,
  });

  /// Parses the native encoding `"<daysBitmask>:<startMins>:<endMins>"`.
  /// Returns null for anything malformed rather than throwing — a garbled slot must
  /// not take down the whole chart.
  static SleepSchedule? tryParse(String encoded) {
    final parts = encoded.split(':');
    if (parts.length != 3) return null;
    final days = int.tryParse(parts[0]);
    final start = int.tryParse(parts[1]);
    final end = int.tryParse(parts[2]);
    if (days == null || start == null || end == null) return null;
    if (days <= 0 || start < 0 || start >= 1440 || end < 0 || end >= 1440) {
      return null;
    }
    return SleepSchedule(
      daysBitmask: days,
      startMinute: start,
      endMinute: end,
    );
  }

  final int daysBitmask;
  final int startMinute;
  final int endMinute;

  /// Whether this slot starts on [weekday] (`DateTime.monday`..`DateTime.sunday`).
  /// Bit 0 is Monday, matching the pump's own mask.
  bool appliesOn(int weekday) => daysBitmask & (1 << (weekday - 1)) != 0;

  /// Runs past midnight — the end lands on the following day.
  bool get wrapsMidnight => endMinute <= startMinute;

  String get label => '${_hhmm(startMinute)}–${_hhmm(endMinute)}';

  static String _hhmm(int minuteOfDay) {
    final h = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
    final m = (minuteOfDay % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// A sleep window projected onto a chart's minutes-from-now x-axis.
class SleepWindow {
  const SleepWindow(this.startMinutesFromNow, this.endMinutesFromNow, this.label);
  final double startMinutesFromNow;
  final double endMinutesFromNow;
  final String label;
}

/// Projects [schedules] onto the window [minMinutes, maxMinutes] minutes from [now],
/// clipped to that range.
///
/// Walks a few days either side of now because a chart spanning midnight has to pick up
/// both the window that started yesterday and the one starting tomorrow — using only
/// today's weekday would drop the half of an overnight window that matters most.
List<SleepWindow> sleepWindowsInRange(
  Iterable<SleepSchedule> schedules,
  DateTime now,
  double minMinutes,
  double maxMinutes,
) {
  final windows = <SleepWindow>[];
  final midnight = DateTime(now.year, now.month, now.day);
  for (var dayOffset = -2; dayOffset <= 2; dayOffset++) {
    final day = midnight.add(Duration(days: dayOffset));
    for (final s in schedules) {
      // The weekday tested is the day the window STARTS on; a Friday-night window
      // running to 07:00 belongs to Friday even though it ends on Saturday.
      if (!s.appliesOn(day.weekday)) continue;
      final start = day.add(Duration(minutes: s.startMinute));
      final end = day.add(Duration(
        minutes: s.endMinute + (s.wrapsMidnight ? 1440 : 0),
      ));
      final startX = start.difference(now).inMinutes.toDouble();
      final endX = end.difference(now).inMinutes.toDouble();
      if (endX <= minMinutes || startX >= maxMinutes) continue;
      windows.add(SleepWindow(
        startX < minMinutes ? minMinutes : startX,
        endX > maxMinutes ? maxMinutes : endX,
        s.label,
      ));
    }
  }
  windows.sort((a, b) =>
      a.startMinutesFromNow.compareTo(b.startMinutesFromNow));
  return windows;
}
