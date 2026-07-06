/// Stale-data watchdog (TASK-176): alerts are driven by snapshot arrival, so if
/// readings stop while the BLE link still looks healthy (sensor fell off at 2am,
/// pump stopped publishing), the last reading is silently treated as current forever
/// and no alert can ever fire. This monitor tracks time-since-last-snapshot
/// INDEPENDENT of the connection stage.
///
/// Pure state machine — all times are passed in, so it unit-tests with an injected
/// clock. A thin provider service owns the periodic timer and the notification.
library;

/// What a monitor transition means for the caller.
enum StaleDataEvent {
  /// Nothing to do.
  none,

  /// The feed just crossed the staleness threshold — alert once.
  becameStale,

  /// A snapshot arrived after a stale period — the stall is over.
  recovered,
}

class StaleDataMonitor {
  StaleDataMonitor({this.threshold = const Duration(minutes: 15)});

  /// How old the last snapshot may get before the feed counts as stalled.
  /// CGM cadence is ~5 min, and the disconnect alert waits 10 — 15 min of
  /// silence on a "healthy" link is three missed readings.
  final Duration threshold;

  DateTime? _lastSnapshotAt;
  bool _stale = false;

  /// Age of the feed at [now], or null before the first snapshot.
  Duration? age(DateTime now) =>
      _lastSnapshotAt == null ? null : now.difference(_lastSnapshotAt!);

  /// Record a snapshot arrival. Returns [StaleDataEvent.recovered] when it ends a
  /// stale period (so the caller can log/clear), otherwise none.
  StaleDataEvent onSnapshot(DateTime at) {
    _lastSnapshotAt = at;
    if (_stale) {
      _stale = false;
      return StaleDataEvent.recovered;
    }
    return StaleDataEvent.none;
  }

  /// Periodic check. Returns [StaleDataEvent.becameStale] exactly once per stall —
  /// a new alert needs a recovery first (one notification per episode). Never
  /// stale before the first snapshot: there is no feed to go stale.
  StaleDataEvent check(DateTime now) {
    final a = age(now);
    if (a == null || _stale || a < threshold) return StaleDataEvent.none;
    _stale = true;
    return StaleDataEvent.becameStale;
  }
}
