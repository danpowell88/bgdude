/// The injected clock actually reaches the time-dependent services (issue #53).
///
/// Every test here pins `clockProvider` to a time that DISAGREES with the wall
/// clock in the direction that matters, so each one fails if the injection is
/// reverted to a bare wall-clock read. The mode tests run in the year 2100: a
/// leaked real clock would see those activations as starting far in the future
/// and could never expire them, so "it expired" is only reachable via the
/// injected time. That is the difference between this and the hollow version —
/// a test using a past expiry with a real clock would pass either way.
library;

import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/faults.dart';

/// A clock the test can wind forward while a container stays alive, so mode
/// activation and its later expiry share one provider graph.
class _FakeClock {
  _FakeClock(this.now);
  DateTime now;
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

void main() {
  /// Container whose services all read [clock]. Mode expiry fires a notification
  /// as a side effect, so this needs the noop service rather than the real one
  /// (which reaches for a platform channel that isn't registered in a unit test).
  late NoopNotificationService notifications;

  ProviderContainer containerWith(_FakeClock clock) {
    notifications = NoopNotificationService();
    final c = ProviderContainer(overrides: [
      historyRepositoryProvider.overrideWithValue(InMemoryHistoryRepository()),
      notificationServiceProvider.overrideWithValue(notifications),
      clockProvider.overrideWithValue(clock.call),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('clockProvider', () {
    test('defaults to the wall clock when nothing overrides it', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final before = DateTime.now(); // now-ok: bounds the default clock's own reading
      final read = c.read(clockProvider)();
      final after = DateTime.now(); // now-ok: bounds the default clock's own reading

      expect(read.isBefore(before), isFalse);
      expect(read.isAfter(after), isFalse);
    });

    test('is distinct from demoClockProvider', () {
      // Conflating the two would make a test that pins app time also silently
      // regenerate the demo feed underneath itself.
      final pinned = DateTime(2030, 5, 5);
      final c = ProviderContainer(
          overrides: [clockProvider.overrideWithValue(() => pinned)]);
      addTearDown(c.dispose);

      expect(c.read(clockProvider)(), pinned);
      expect(c.read(demoClockProvider)(), isNot(pinned));
    });
  });

  group('illness mode expiry is driven by the injected clock', () {
    test('activates at the pinned time and auto-expires only once it is passed',
        () async {
      final clock = _FakeClock(DateTime(2100, 1, 1));
      final container = containerWith(clock);

      container.read(illnessModeProvider.notifier).activate(boost: 1.2);
      await pumpEventQueue();

      final mode = container.read(illnessModeProvider);
      expect(mode.active, isTrue);
      // Stamped from the injected clock, not the wall clock.
      expect(mode.startedAt, clock.now);
      expect(mode.expiresAt, DateTime(2100, 1, 8));

      // Six days in: inside the 7-day window, must survive the expiry sweep.
      clock.advance(const Duration(days: 6));
      await container.read(appJobsProvider).checkModeExpiry();
      await pumpEventQueue();
      expect(container.read(illnessModeProvider).active, isTrue,
          reason: 'still inside the 7-day window');

      // Two days later: past it, so the sweep must end the mode. Unreachable on
      // a real clock, which would still be in 2026.
      clock.advance(const Duration(days: 2));
      await container.read(appJobsProvider).checkModeExpiry();
      await pumpEventQueue();
      expect(container.read(illnessModeProvider).active, isFalse,
          reason: 'the injected clock is past the expiry — a real wall-clock read '
              'would leave a 2100 activation active forever');
      // Auto-expiry must tell the user dosing hints reverted, not revert silently.
      expect(notifications.shown, contains(NotificationCategory.modeExpired));
    });

    test('a manual deactivation does not wait for the clock', () async {
      final clock = _FakeClock(DateTime(2100, 1, 1));
      final container = containerWith(clock);
      final illness = container.read(illnessModeProvider.notifier);

      illness.activate(boost: 1.2);
      await pumpEventQueue();
      expect(container.read(illnessModeProvider).active, isTrue);

      illness.deactivate();
      await pumpEventQueue();

      // Expiry is a backstop, not the only way out — the user ending a sick day
      // must take effect immediately regardless of where the clock sits.
      expect(container.read(illnessModeProvider).active, isFalse);
    });
  });

  group('stale-data watchdog ages the feed against the injected clock', () {
    /// The watchdog needs a connected pump: it deliberately owns only the
    /// connected-but-silent case (a real disconnect is ConnectionAlertService's).
    ProviderContainer watchdogContainer(
        _FakeClock clock, ThrowingNotificationService notifier) {
      final c = ProviderContainer(overrides: [
        notificationServiceProvider.overrideWithValue(notifier),
        pumpConnectionProvider.overrideWith((ref) =>
            Stream.value(const PumpConnection(stage: PumpConnectionStage.connected))),
        clockProvider.overrideWithValue(clock.call),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('a feed that goes silent past the threshold alerts, and not before',
        () async {
      final clock = _FakeClock(DateTime(2100, 1, 1));
      final notifier = ThrowingNotificationService()..shouldThrow = false;
      final container = watchdogContainer(clock, notifier);
      await container.read(pumpConnectionProvider.future);
      final service = container.read(staleDataWatchdogProvider);

      // A snapshot arrives "now" on the injected clock — no contrived subtraction
      // from the wall clock needed, which is the point of the seam.
      service.monitor.onSnapshot(clock.now);

      clock.advance(const Duration(minutes: 5));
      await service.checkNow();
      expect(notifier.shown, isNot(contains(NotificationCategory.dataStale)),
          reason: '5 minutes of silence is not yet a stalled feed');

      clock.advance(const Duration(minutes: 20));
      await service.checkNow();
      expect(notifier.shown, contains(NotificationCategory.dataStale),
          reason: 'the injected clock is 25 minutes past the last snapshot — '
              'against a real wall-clock read the age would be negative (the '
              'snapshot is stamped in 2100) and never read as stale');
    });
  });

  group('constructor defaults', () {
    test('the services fall back to the wall clock with no override', () {
      // The providers wire clockProvider in, but these classes are also
      // constructible directly; the default must stay the real clock so
      // production behaviour is unchanged by this refactor.
      final c = ProviderContainer(overrides: [
        historyRepositoryProvider.overrideWithValue(InMemoryHistoryRepository()),
        notificationServiceProvider.overrideWithValue(NoopNotificationService()),
      ]);
      addTearDown(c.dispose);

      expect(c.read(appJobsProvider), isA<AppJobs>());
      expect(c.read(alertServiceProvider), isA<AlertService>());
      expect(c.read(illnessModeProvider).active, isFalse);
    });
  });
}
