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
