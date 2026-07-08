import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/pump/battery_drain.dart';
import 'package:bgdude/pump/battery_history.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

List<BatterySample> _discharge(DateTime start, int fromPct, double perHour,
    {int stepMin = 30, int count = 8, bool? charging = false}) {
  final out = <BatterySample>[];
  for (var i = 0; i < count; i++) {
    final t = start.add(Duration(minutes: stepMin * i));
    final pct = (fromPct - perHour * (stepMin * i) / 60.0).round();
    out.add(BatterySample(time: t, percent: pct, charging: charging));
  }
  return out;
}

void main() {
  const est = BatteryDrainEstimator();

  group('BatteryDrainEstimator', () {
    test('extrapolates a steady discharge to an ETA', () {
      final now = DateTime(2026, 7, 4, 20);
      // 60% now, dropping ~5%/h over the last few hours.
      final samples = _discharge(now.subtract(const Duration(hours: 3, minutes: 30)),
          77, 5, count: 8);
      final e = est.estimate(samples, now: now);
      expect(e.hasEstimate, isTrue);
      expect(e.charging, isFalse);
      expect(e.percentPerHour, closeTo(5, 0.5));
      // ~60% / 5%/h ≈ 12 h.
      expect(e.timeToEmpty!.inHours, inInclusiveRange(10, 14));
      expect(e.emptyAt, isNotNull);
    });

    test('no ETA while charging', () {
      final now = DateTime(2026, 7, 4, 20);
      final samples = [
        ..._discharge(now.subtract(const Duration(hours: 3)), 40, 5, count: 6),
        BatterySample(time: now, percent: 45, charging: true),
      ];
      final e = est.estimate(samples, now: now);
      expect(e.charging, isTrue);
      expect(e.hasEstimate, isFalse);
    });

    test('a charge event resets the run (only the latest discharge counts)', () {
      final now = DateTime(2026, 7, 4, 20);
      final samples = <BatterySample>[
        // Old discharge, then a charge back up…
        ..._discharge(now.subtract(const Duration(hours: 9)), 30, 6, count: 4),
        BatterySample(
            time: now.subtract(const Duration(hours: 6)), percent: 95, charging: true),
        // …then a fresh, slower discharge.
        ..._discharge(now.subtract(const Duration(hours: 4)), 90, 3, count: 8),
      ];
      final e = est.estimate(samples, now: now);
      expect(e.hasEstimate, isTrue);
      expect(e.percentPerHour, closeTo(3, 0.6)); // the recent slope, not the old 6%/h
    });

    test('not enough data → no estimate', () {
      final now = DateTime(2026, 7, 4, 20);
      final e = est.estimate([
        BatterySample(time: now.subtract(const Duration(minutes: 10)), percent: 80),
        BatterySample(time: now, percent: 79),
      ], now: now);
      expect(e.hasEstimate, isFalse);
    });

    test('a rising (charging-ish) trend yields no drain ETA', () {
      final now = DateTime(2026, 7, 4, 20);
      final rising = [
        for (var i = 0; i < 6; i++)
          BatterySample(
              time: now.subtract(Duration(minutes: 30 * (5 - i))),
              percent: 50 + i * 5,
              charging: false),
      ];
      expect(est.estimate(rising, now: now).hasEstimate, isFalse);
    });
  });

  group('BatteryHistoryStore', () {
    setUp(KvStore.useMemory);

    test('appends changed samples and de-dups steady ones', () async {
      final t = DateTime(2026, 7, 4, 12);
      await BatteryHistoryStore.append(
          BatterySample(time: t, percent: 80, charging: false));
      // Same %/charging a minute later → skipped.
      await BatteryHistoryStore.append(BatterySample(
          time: t.add(const Duration(minutes: 1)), percent: 80, charging: false));
      // Changed % → kept.
      await BatteryHistoryStore.append(BatterySample(
          time: t.add(const Duration(minutes: 30)), percent: 79, charging: false));
      final samples = await BatteryHistoryStore.load();
      expect(samples, hasLength(2));
      expect(samples.last.percent, 79);
    });
  });

  group('PumpSnapshot.isCharging', () {
    test('parses isCharging from JSON', () {
      final s = PumpSnapshot.fromJson({
        'timestampEpochMs': 1_700_000_000_000,
        'batteryPercent': 42,
        'isCharging': true,
      });
      expect(s.batteryPercent, 42);
      expect(s.isCharging, isTrue);
    });

    test('isCharging null when absent (V1 pumps)', () {
      final s = PumpSnapshot.fromJson({
        'timestampEpochMs': 1_700_000_000_000,
        'batteryPercent': 42,
      });
      expect(s.isCharging, isNull);
    });
  });
}
