/// Parameterized boundary probes at the clinical thresholds (54/70/180/250).
/// Off-by-comparison errors at these cut points are the most common clinical-logic
/// bug class; each case documents which side the EXACT threshold belongs to.
///
/// Intended inclusivity (pinned here):
///  * below54:  mgdl < 54    (54.0 itself is NOT "very low")
///  * below70:  mgdl < 70    (70.0 itself is IN RANGE)
///  * in range: 70 <= mgdl <= 180 (both ends inclusive)
///  * above180: mgdl > 180   (180.0 itself is IN RANGE)
///  * above250: mgdl > 250   (250.0 itself is high but NOT "very high")
///  * advisor low-guard: current < 70 blocks the correction (70.0 doses normally)
///  * stubborn-high run:  mgdl > 180 strictly (a flat 180.0 never qualifies)
///  * urgent-low forecast: predicted < urgent line strictly (54.0 exactly is a
///    plain predicted low, not urgent)
library;

import 'package:bgdude/analytics/bolus_advisor.dart';
import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/insights/alert_monitor.dart';
import 'package:bgdude/insights/care_detectors.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/samples.dart';

void main() {
  final now = DateTime(2026, 7, 4, 12);

  group('TIR band boundaries (MetricsCalculator)', () {
    ({double below54, double below70, double inRange, double above180, double above250})
        bandsAt(double mgdl) {
      final m = const MetricsCalculator()
          .compute(flatTrace(start: now, count: 10, mgdl: mgdl));
      return (
        below54: m.timeBelow54,
        below70: m.timeBelow70,
        inRange: m.timeInRange,
        above180: m.timeAbove180,
        above250: m.timeAbove250,
      );
    }

    test('69.9 is low; 70.0 and 70.1 are in range (low bound inclusive)', () {
      expect(bandsAt(69.9).below70, 1.0);
      expect(bandsAt(69.9).inRange, 0.0);
      expect(bandsAt(70.0).inRange, 1.0);
      expect(bandsAt(70.0).below70, 0.0);
      expect(bandsAt(70.1).inRange, 1.0);
    });

    test('53.9 is very low; 54.0 is low but NOT very low', () {
      expect(bandsAt(53.9).below54, 1.0);
      expect(bandsAt(54.0).below54, 0.0);
      expect(bandsAt(54.0).below70, 1.0);
    });

    test('179.9 and 180.0 are in range; 180.1 is high (high bound inclusive)', () {
      expect(bandsAt(179.9).inRange, 1.0);
      expect(bandsAt(180.0).inRange, 1.0);
      expect(bandsAt(180.0).above180, 0.0);
      expect(bandsAt(180.1).above180, 1.0);
      expect(bandsAt(180.1).inRange, 0.0);
    });

    test('249.9 and 250.0 are high but not very high; 250.1 is very high', () {
      expect(bandsAt(249.9).above250, 0.0);
      expect(bandsAt(250.0).above250, 0.0);
      expect(bandsAt(250.0).above180, 1.0);
      expect(bandsAt(250.1).above250, 1.0);
    });
  });

  group('bolus-advisor low-guard boundary (P0-6)', () {
    PredictionState stateAt(double bg) => PredictionState(
          now: now,
          currentMgdl: bg,
          recentRocMgdlPerMin: 0,
          boluses: const [],
          basal: const [],
          carbs: const [],
          settings: testTherapySettings(),
        );

    test('69.9 blocks the correction; 70.0 doses normally', () {
      // Guard is `current < 70`: exactly 70 is treated as in range.
      expect(BolusAdvisor().computeBolus(stateAt(69.9)).currentlyLow, isTrue);
      expect(BolusAdvisor().computeBolus(stateAt(70.0)).currentlyLow, isFalse);
      expect(BolusAdvisor().computeBolus(stateAt(70.1)).currentlyLow, isFalse);
    });
  });

  group('stubborn-high run boundary', () {
    List<CgmSample> flatHigh(double mgdl) => sustained(end: now, mgdl: mgdl, count: 31);
    final boluses = [
      BolusEvent(time: now.subtract(const Duration(minutes: 30)), units: 3)
    ];

    StubbornHighAlert? detect(double mgdl) => const StubbornHighDetector().detect(
          cgm: flatHigh(mgdl),
          boluses: boluses,
          basal: const [],
          settings: testTherapySettings(),
          now: now,
        );

    test('a flat 180.0 never qualifies (strictly above 180 required)', () {
      expect(detect(180.0), isNull);
      expect(detect(179.9), isNull);
    });

    test('a flat 180.1 with IOB does qualify', () {
      expect(detect(180.1), isNotNull);
    });
  });

  group('urgent-low forecast boundary (AlertMonitor)', () {
    GlucoseAlert? evaluate(double predictedMgdl) =>
        const AlertMonitor(lowMgdl: 70, urgentLowMgdl: 54, cooldown: Duration.zero)
            .evaluate(
          forecasts: [
            HorizonForecast(
                horizonMinutes: 20,
                mgdl: predictedMgdl,
                lowerMgdl: predictedMgdl - 5,
                upperMgdl: predictedMgdl + 5),
          ],
          currentMgdl: 100,
          now: now,
          lastFired: const {},
        );

    test('a predicted 53.9 is URGENT; exactly 54.0 is a plain predicted low', () {
      expect(evaluate(53.9)!.kind, GlucoseAlertKind.urgentLow);
      expect(evaluate(54.0)!.kind, GlucoseAlertKind.predictedLow);
    });

    test('a predicted 69.9 alerts; exactly 70.0 does not (strictly below)', () {
      expect(evaluate(69.9), isNotNull);
      expect(evaluate(69.9)!.kind, GlucoseAlertKind.predictedLow);
      expect(evaluate(70.0), isNull);
    });
  });
}
