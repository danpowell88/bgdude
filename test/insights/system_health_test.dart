import 'package:bgdude/insights/system_health.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubsystemHealth', () {
    test('unknown/never-observed is not unhealthy', () {
      expect(SubsystemHealth.unknown.isUnhealthy, isFalse);
      expect(SubsystemHealth.unknown.lastAttemptAt, isNull);
    });

    test('withSuccess resets consecutiveFailures to 0', () {
      final now = DateTime(2026, 7, 8, 8);
      final afterFailures = SubsystemHealth.unknown
          .withFailure(now, 'boom')
          .withFailure(now, 'boom again');
      expect(afterFailures.consecutiveFailures, 2);
      expect(afterFailures.isUnhealthy, isTrue);

      final recovered = afterFailures.withSuccess(now);
      expect(recovered.consecutiveFailures, 0);
      expect(recovered.lastError, isNull);
      expect(recovered.isUnhealthy, isFalse);
      expect(recovered.lastSuccessAt, now);
    });

    test('withFailure keeps the previous lastSuccessAt (does not erase history)', () {
      final firstSuccess = DateTime(2026, 7, 1);
      final afterSuccess = SubsystemHealth.unknown.withSuccess(firstSuccess);
      final afterFailure =
          afterSuccess.withFailure(DateTime(2026, 7, 8), 'timed out');
      expect(afterFailure.lastSuccessAt, firstSuccess);
      expect(afterFailure.consecutiveFailures, 1);
      expect(afterFailure.isUnhealthy, isTrue);
    });

    test('never succeeded but has been attempted is unhealthy', () {
      final h = SubsystemHealth.unknown.withFailure(DateTime(2026, 7, 8), 'x');
      expect(h.lastSuccessAt, isNull);
      expect(h.isUnhealthy, isTrue);
    });

    test('JSON round-trip', () {
      final h = SubsystemHealth(
        lastSuccessAt: DateTime(2026, 7, 1, 9),
        consecutiveFailures: 3,
        lastError: 'network unreachable',
        lastAttemptAt: DateTime(2026, 7, 8, 10),
      );
      final restored = SubsystemHealth.fromJson(h.toJson());
      expect(restored.lastSuccessAt, h.lastSuccessAt);
      expect(restored.consecutiveFailures, 3);
      expect(restored.lastError, 'network unreachable');
      expect(restored.lastAttemptAt, h.lastAttemptAt);
    });
  });

  // TASK-265: isUnhealthy alone can't see the most common and most dangerous
  // background-failure mode -- a job that silently stops being scheduled at all
  // never throws, so consecutiveFailures never increments and the row would show a
  // permanent green check with an ever-growing "last success N days ago".
  group('SubsystemHealth.isStale', () {
    test(
        'a subsystem with an old last-success and no recent attempt reads stale, '
        'not healthy', () {
      final now = DateTime(2026, 7, 8);
      final longAgo = now.subtract(const Duration(hours: 72));
      final h = SubsystemHealth.unknown.withSuccess(longAgo);

      expect(h.isUnhealthy, isFalse,
          reason: 'no recorded failure -- this is exactly the silent-stall case '
              'isUnhealthy cannot see on its own');
      expect(h.isStale(now, const Duration(hours: 48)), isTrue);
    });

    test('a recent success within the cadence is not stale', () {
      final now = DateTime(2026, 7, 8);
      final recent = now.subtract(const Duration(hours: 2));
      final h = SubsystemHealth.unknown.withSuccess(recent);

      expect(h.isStale(now, const Duration(hours: 48)), isFalse);
    });

    test('a null cadence never reads stale, no matter how old the success', () {
      final now = DateTime(2026, 7, 8);
      final longAgo = now.subtract(const Duration(days: 365));
      final h = SubsystemHealth.unknown.withSuccess(longAgo);

      expect(h.isStale(now, null), isFalse,
          reason: 'no real schedule to compare against (e.g. weather, '
              'modelDownload) -- must not invent one');
    });

    test('never having succeeded is never "stale" (that is isUnhealthy\'s case)',
        () {
      final now = DateTime(2026, 7, 8);
      expect(
          SubsystemHealth.unknown.isStale(now, const Duration(hours: 48)),
          isFalse,
          reason: 'no lastSuccessAt at all means "never run", a distinct state '
              'from "ran, but too long ago"');
    });

    test('a real recorded failure takes priority over mere staleness', () {
      final now = DateTime(2026, 7, 8);
      final longAgo = now.subtract(const Duration(hours: 72));
      final h = SubsystemHealth.unknown
          .withSuccess(longAgo)
          .withFailure(now, 'boom');

      expect(h.isUnhealthy, isTrue);
      expect(h.isStale(now, const Duration(hours: 48)), isFalse,
          reason: 'isUnhealthy already covers this and is worse -- isStale must '
              'not ALSO fire, or a caller checking both independently could show '
              'conflicting amber-and-red state for the same row');
    });
  });

  group('Subsystem.expectedCadence', () {
    test('the three app-open-driven subsystems have a real, non-null cadence', () {
      expect(Subsystem.healthSync.expectedCadence, isNotNull);
      expect(Subsystem.predictionReconciliation.expectedCadence, isNotNull);
      expect(Subsystem.forecasterTraining.expectedCadence, isNotNull);
    });

    test(
        'subsystems with no real periodic schedule are excluded, not given a '
        'guessed number', () {
      expect(Subsystem.weather.expectedCadence, isNull,
          reason: 'no periodic refresh exists anywhere in the codebase');
      expect(Subsystem.modelDownload.expectedCadence, isNull,
          reason: 'one-shot, user-triggered, not a recurring job');
      expect(Subsystem.garminDelivery.expectedCadence, isNull,
          reason: 'reported via a separate native path -- this enum entry in '
              'SystemHealthReport is never populated at all');
    });
  });

  group('SystemHealthReport', () {
    test('of() returns unknown for a subsystem never recorded', () {
      const report = SystemHealthReport();
      expect(report.of(Subsystem.weather), SubsystemHealth.unknown);
    });

    test('withRecord only touches the named subsystem', () {
      const report = SystemHealthReport();
      final now = DateTime(2026, 7, 8);
      final updated = report.withRecord(
          Subsystem.healthSync, SubsystemHealth.unknown.withSuccess(now));
      expect(updated.of(Subsystem.healthSync).lastSuccessAt, now);
      expect(updated.of(Subsystem.weather), SubsystemHealth.unknown);
    });

    test('JSON round-trip preserves per-subsystem state', () {
      final now = DateTime(2026, 7, 8);
      final report = const SystemHealthReport()
          .withRecord(Subsystem.healthSync, SubsystemHealth.unknown.withSuccess(now))
          .withRecord(Subsystem.weather,
              SubsystemHealth.unknown.withFailure(now, 'no data'));
      final restored = SystemHealthReport.fromJson(report.toJson());
      expect(restored.of(Subsystem.healthSync).lastSuccessAt, now);
      expect(restored.of(Subsystem.weather).consecutiveFailures, 1);
      expect(restored.of(Subsystem.garminDelivery), SubsystemHealth.unknown);
    });
  });
}
