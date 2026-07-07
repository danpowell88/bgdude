import 'package:bgdude/data/health_sync.dart';
import 'package:bgdude/ml/forecast_features.dart';
import 'package:bgdude/ml/health_features.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HealthFeatureSampler', () {
    final t0 = DateTime(2026, 7, 4, 12);

    test('no data → zero features at any time', () {
      final s = HealthFeatureSampler(const []);
      expect(s.featuresAt(t0), HealthFeatureSampler.zeros);
      expect(s.featuresAt(t0).length, HealthFeatureSampler.featureCount);
    });

    test('recent steps raise the activity feature; brisk walk ≈ 1.0', () {
      // 3000 steps over the 30-min window = 100 steps/min = brisk → activity 1.0.
      final samples = [
        for (var m = 29; m >= 0; m--)
          HealthSample(
              time: t0.subtract(Duration(minutes: m)),
              type: HealthMetric.steps,
              value: 100),
      ];
      final s = HealthFeatureSampler(samples);
      final f = s.featuresAt(t0);
      expect(f[0], closeTo(1.0, 1e-9));
      // Steps that are old (outside the window) don't count.
      expect(s.featuresAt(t0.add(const Duration(hours: 2)))[0], 0);
    });

    test('P2-7: a future resting-HR reading does not change a past feature', () {
      final base = [
        HealthSample(
            time: t0.subtract(const Duration(days: 1)),
            type: HealthMetric.restingHr,
            value: 60),
        HealthSample(
            time: t0.subtract(const Duration(minutes: 2)),
            type: HealthMetric.heartRate,
            value: 90),
      ];
      final before = HealthFeatureSampler(base).featuresAt(t0)[2]; // hr_rel
      expect(before, greaterThan(0)); // hr 90 vs resting 60 → elevated
      // Adding a resting-HR reading AFTER t0 (very different) must not change it.
      final withFuture = HealthFeatureSampler([
        ...base,
        HealthSample(
            time: t0.add(const Duration(hours: 6)),
            type: HealthMetric.restingHr,
            value: 120),
      ]).featuresAt(t0)[2];
      expect(withFuture, closeTo(before, 1e-9));
    });

    test('P2-7: activity sums exactly the trailing (from, t] window', () {
      final s = HealthFeatureSampler([
        HealthSample( // 40 min ago — outside the 30-min window
            time: t0.subtract(const Duration(minutes: 40)),
            type: HealthMetric.steps,
            value: 500),
        HealthSample(
            time: t0.subtract(const Duration(minutes: 20)),
            type: HealthMetric.steps,
            value: 1500),
        HealthSample(
            time: t0.subtract(const Duration(minutes: 5)),
            type: HealthMetric.steps,
            value: 1500),
        HealthSample( // future — excluded
            time: t0.add(const Duration(minutes: 5)),
            type: HealthMetric.steps,
            value: 9999),
      ]);
      // In-window steps = 3000 over 30 min = 100/min = brisk → 1.0.
      expect(s.featuresAt(t0)[0], closeTo(1.0, 1e-9));
    });

    test('activity feature is clamped at 1.5 for very intense movement', () {
      final samples = [
        HealthSample(
            time: t0.subtract(const Duration(minutes: 5)),
            type: HealthMetric.steps,
            value: 9000),
      ];
      expect(HealthFeatureSampler(samples).featuresAt(t0)[0], 1.5);
    });

    test('post-workout recency is 1.0 mid-workout and decays by half-life', () {
      // A 60-min workout starting 60 min before t0 → ends exactly at t0.
      final samples = [
        HealthSample(
            time: t0.subtract(const Duration(minutes: 60)),
            type: HealthMetric.exercise,
            value: 60),
      ];
      final s = HealthFeatureSampler(samples);
      // Mid-workout (30 min in).
      expect(s.featuresAt(t0.subtract(const Duration(minutes: 30)))[1], 1.0);
      // Right at the end.
      expect(s.featuresAt(t0)[1], closeTo(1.0, 1e-9));
      // One half-life (90 min) after the end → ~0.5.
      expect(s.featuresAt(t0.add(const Duration(minutes: 90)))[1],
          closeTo(0.5, 1e-6));
      // Well beyond the window → 0.
      expect(s.featuresAt(t0.add(const Duration(hours: 5)))[1], 0);
    });

    test('elevated heart rate vs resting baseline raises the hr feature', () {
      final samples = [
        HealthSample(
            time: t0.subtract(const Duration(days: 1)),
            type: HealthMetric.restingHr,
            value: 60),
        HealthSample(
            time: t0.subtract(const Duration(minutes: 5)),
            type: HealthMetric.heartRate,
            value: 90), // +50% over resting
      ];
      final s = HealthFeatureSampler(samples);
      // (90-60)/60 = 0.5.
      expect(s.featuresAt(t0)[2], closeTo(0.5, 1e-9));
      // No recent HR reading → 0.
      expect(s.featuresAt(t0.add(const Duration(hours: 2)))[2], 0);
    });

    test('no resting baseline → hr feature is 0', () {
      final samples = [
        HealthSample(time: t0, type: HealthMetric.heartRate, value: 120),
      ];
      expect(HealthFeatureSampler(samples).featuresAt(t0)[2], 0);
    });
  });

  group('ForecastFeatures with health', () {
    test('vector length and names include the health features (v4)', () {
      expect(ForecastFeatures.version, 4);
      final v = ForecastFeatures.build(
        now: DateTime(2026, 7, 4, 9),
        currentMgdl: 140,
        recentRocMgdlPerMin: 0.5,
        boluses: const [],
        basal: const [],
        carbs: const [],
        horizonMinutes: 30,
      );
      expect(v.length, ForecastFeatures.names.length);
      expect(ForecastFeatures.names,
          containsAll(['activity', 'exercise_recency', 'hr_rel']));
      // Default health contribution is zeros (trailing three features).
      expect(v.sublist(v.length - 3), [0.0, 0.0, 0.0]);
    });

    test('supplied health features land in the trailing slots', () {
      final v = ForecastFeatures.build(
        now: DateTime(2026, 7, 4, 9),
        currentMgdl: 140,
        recentRocMgdlPerMin: 0.5,
        boluses: const [],
        basal: const [],
        carbs: const [],
        horizonMinutes: 30,
        health: const [0.8, 0.3, 0.4],
      );
      expect(v.sublist(v.length - 3), [0.8, 0.3, 0.4]);
    });
  });
}
