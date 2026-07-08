import 'package:bgdude/core/samples.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import 'faults.dart';

/// Each fault-injecting double gets adopted by at least one test here;
/// tests that need a specific failure scenario (alert loop, snapshot chain,
/// runStartup, ...) build on top of these instead of writing another ad-hoc double.
void main() {
  group('FaultInjectingHistoryRepository', () {
    test('failOn makes one method throw while an unrelated method on the same '
        'instance keeps delegating normally', () async {
      final repo = FaultInjectingHistoryRepository();
      final t = DateTime(2026, 7, 8, 9);
      await repo.saveCgm([CgmSample(time: t, mgdl: 110, trend: GlucoseTrend.flat)]);

      repo.failOn('cgm');
      expect(() => repo.cgm(t, t), throwsStateError);

      // A different method on the same instance is unaffected by the cgm-only failure.
      await repo.saveBolus(BolusEvent(time: t, units: 1.0));
      expect((await repo.boluses(t, t)).single.units, 1.0);

      repo.clearFailOn('cgm');
      expect(await repo.cgm(t, t), hasLength(1)); // saveCgm's earlier write survived
    });

    test('throwOnce throws exactly once then behaves normally', () async {
      final repo = FaultInjectingHistoryRepository();
      repo.throwOnce('earliestCgm');

      expect(() => repo.earliestCgm(), throwsStateError);
      expect(await repo.earliestCgm(), isNull); // second call succeeds
    });
  });

  group('ThrowingNotificationService', () {
    test('records the attempted category and throws instead of showing', () async {
      final svc = ThrowingNotificationService();
      await expectLater(
        () => svc.show(NotificationCategory.urgentLow, 'title', 'body'),
        throwsStateError,
      );
      expect(svc.shown, [NotificationCategory.urgentLow]);
    });
  });

  group('ErroringPumpSource', () {
    test('failOn(method) throws only for that command; streams stay controllable', () async {
      final source = ErroringPumpSource();
      source.failOn('startScan');

      await expectLater(() => source.startScan(), throwsStateError);
      await source.stopScan(); // not in failing set -- succeeds

      final snapshot = PumpSnapshot(time: DateTime(2026, 7, 8), cgmMgdl: 100);
      final received = <PumpSnapshot>[];
      final sub = source.snapshots.listen(received.add);
      source.emitSnapshot(snapshot);
      await Future<void>.delayed(Duration.zero);
      expect(received, [snapshot]);
      expect(source.lastSnapshot, snapshot);
      await sub.cancel();
      await source.dispose();
    });
  });

  group('ThrowingHealthSyncService', () {
    test('fetch throws by default; requestPermissions succeeds by default', () async {
      final svc = ThrowingHealthSyncService();
      await expectLater(
        () => svc.fetch(DateTime(2026, 7, 1), DateTime(2026, 7, 8)),
        throwsStateError,
      );
      expect(await svc.requestPermissions(), isTrue);

      svc.failPermissions = true;
      await expectLater(() => svc.requestPermissions(), throwsStateError);
    });
  });
}
