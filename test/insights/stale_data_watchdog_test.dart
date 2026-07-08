/// TASK-176: the stale-data watchdog fires when readings stop while the link looks
/// healthy, once per stall, and recovers when data flows again. Pure monitor —
/// every time is injected.
library;

import 'package:bgdude/insights/stale_data_watchdog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 7, 4, 2); // the 2am sensor-fall-off story

  test('never stale before the first snapshot', () {
    final m = StaleDataMonitor();
    expect(m.check(t0), StaleDataEvent.none);
    expect(m.check(t0.add(const Duration(hours: 5))), StaleDataEvent.none);
    expect(m.age(t0), isNull);
  });

  test('quiet while readings keep arriving', () {
    final m = StaleDataMonitor();
    for (var i = 0; i < 6; i++) {
      m.onSnapshot(t0.add(Duration(minutes: 5 * i)));
      expect(m.check(t0.add(Duration(minutes: 5 * i + 4))), StaleDataEvent.none);
    }
  });

  test('no snapshot for the threshold -> becameStale, exactly once', () {
    final m = StaleDataMonitor();
    m.onSnapshot(t0);
    expect(m.check(t0.add(const Duration(minutes: 10))), StaleDataEvent.none);
    expect(
        m.check(t0.add(const Duration(minutes: 15))), StaleDataEvent.becameStale);
    // Persisting stall: one notification per episode, no re-fire.
    expect(m.check(t0.add(const Duration(minutes: 20))), StaleDataEvent.none);
    expect(m.check(t0.add(const Duration(hours: 2))), StaleDataEvent.none);
  });

  test('a snapshot after a stall recovers, and a NEW stall re-alerts', () {
    final m = StaleDataMonitor();
    m.onSnapshot(t0);
    expect(
        m.check(t0.add(const Duration(minutes: 16))), StaleDataEvent.becameStale);
    // Recovery clears the episode.
    expect(m.onSnapshot(t0.add(const Duration(minutes: 21))),
        StaleDataEvent.recovered);
    expect(m.check(t0.add(const Duration(minutes: 25))), StaleDataEvent.none);
    // A fresh stall fires again.
    expect(m.check(t0.add(const Duration(minutes: 36))),
        StaleDataEvent.becameStale);
  });

  test('a snapshot arriving without a prior stall is not a recovery', () {
    final m = StaleDataMonitor();
    m.onSnapshot(t0);
    expect(m.onSnapshot(t0.add(const Duration(minutes: 5))),
        StaleDataEvent.none);
  });

  test('age reports the feed staleness', () {
    final m = StaleDataMonitor();
    m.onSnapshot(t0);
    expect(m.age(t0.add(const Duration(minutes: 12))),
        const Duration(minutes: 12));
  });

  // TASK-230: reset() is used when a caller hands staleness off to a different
  // alert (a BLE disconnect) -- a later reconnect must start fresh, not
  // immediately re-flag on the age that accrued while disconnected.
  test('reset forgets the last snapshot and any stale flag', () {
    final m = StaleDataMonitor();
    m.onSnapshot(t0);
    expect(
        m.check(t0.add(const Duration(minutes: 20))), StaleDataEvent.becameStale);

    m.reset();

    expect(m.age(t0.add(const Duration(minutes: 21))), isNull);
    // No stale carried over, and no feed to go stale until a snapshot arrives.
    expect(m.check(t0.add(const Duration(hours: 5))), StaleDataEvent.none);
  });
}
