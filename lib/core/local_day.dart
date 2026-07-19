/// Local calendar-day boundaries that survive daylight saving (issue #108).
///
/// `dayStart.add(const Duration(days: 1))` adds exactly 24 hours. A local day is only 24
/// hours when the timezone doesn't shift:
///
///  * **Spring forward** the day is 23 hours, so +24h overshoots into 01:00 the next day
///    and the window swallows an hour that belongs to tomorrow.
///  * **Fall back** the day is 25 hours, so +24h lands at 23:00 and the window silently
///    drops the last hour of the day.
///
/// Either way a day's readings get attributed to the wrong day, which matters most in the
/// time-of-day sensitivity model — the thing that feeds dosing advice.
///
/// `DateTime(y, m, d + 1)` is calendar arithmetic: Dart resolves it to the next local
/// midnight whatever the offset does in between. Use these helpers rather than adding
/// durations to a day boundary.
///
/// **Note for anyone testing this:** most Australian development happens in Brisbane
/// (UTC+10, no DST) and CI runs in UTC, so on both machines the two forms agree and a
/// plain-`DateTime` test cannot tell them apart. `test/core/local_day_test.dart` uses the
/// `timezone` package with an explicit DST zone so the property is actually checked.
library;

/// Local midnight starting the calendar day containing [t].
DateTime startOfLocalDay(DateTime t) => DateTime(t.year, t.month, t.day);

/// Local midnight ending the calendar day containing [t] (i.e. the next day's start).
DateTime endOfLocalDay(DateTime t) => DateTime(t.year, t.month, t.day + 1);

/// The calendar day [days] after the day containing [t], at local midnight.
///
/// Handles month and year rollover: `DateTime(2026, 12, 32)` is 2027-01-01.
DateTime addLocalDays(DateTime t, int days) =>
    DateTime(t.year, t.month, t.day + days);

/// Half-open `[start, end)` local-day window containing [t].
({DateTime start, DateTime end}) localDayWindow(DateTime t) =>
    (start: startOfLocalDay(t), end: endOfLocalDay(t));

/// Whether [t] falls in the local calendar day containing [day].
///
/// Half-open on purpose: a reading at exactly midnight belongs to the day starting then,
/// not the one ending then. Without that, a midnight reading is counted in both days.
bool isSameLocalDay(DateTime t, DateTime day) {
  final w = localDayWindow(day);
  return !t.isBefore(w.start) && t.isBefore(w.end);
}
