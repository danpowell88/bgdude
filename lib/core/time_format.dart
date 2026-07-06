/// Shared, local-time clock/date formatting (TASK-107). Replaces the hand-rolled
/// `padLeft` copies scattered across screens so the app formats times one way.
library;

String _p2(int n) => n.toString().padLeft(2, '0');

/// `HH:MM` (24-hour, local).
String formatHhmm(DateTime t) => '${_p2(t.hour)}:${_p2(t.minute)}';

/// `HH:MM:SS` (24-hour, local) — for the developer/protocol timeline.
String formatHhmmss(DateTime t) => '${formatHhmm(t)}:${_p2(t.second)}';

/// `M/D HH:MM` (local) — the compact "when" used in episode and journal lists.
String formatShortDateTime(DateTime t) => '${t.month}/${t.day} ${formatHhmm(t)}';
