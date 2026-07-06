import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/ml/error_grid.dart';
import 'package:flutter_test/flutter_test.dart';

GlucoseMetrics _metrics({
  required double timeInRange,
  required double timeBelow70,
  required double timeBelow54,
  required double timeAbove180,
  required double timeAbove250,
}) =>
    GlucoseMetrics(
      readingCount: 288,
      meanMgdl: 150,
      sdMgdl: 40,
      timeInRange: timeInRange,
      timeInTightRange: timeInRange,
      timeBelow70: timeBelow70,
      timeBelow54: timeBelow54,
      timeAbove180: timeAbove180,
      timeAbove250: timeAbove250,
      coveragePeriod: const Duration(days: 1),
      expectedReadings: 288,
      sufficient: false,
    );

void main() {
  group('TirBands (TASK-105)', () {
    test('decomposes cumulative fractions into exclusive bands that sum to ~1', () {
      // Cumulative: <54 3%, <70 8%, in-range 70%, >180 22%, >250 7%.
      final m = _metrics(
        timeInRange: 0.70,
        timeBelow70: 0.08,
        timeBelow54: 0.03,
        timeAbove180: 0.22,
        timeAbove250: 0.07,
      );
      final b = m.bands;
      expect(b.veryLow, closeTo(0.03, 1e-9));
      expect(b.low, closeTo(0.05, 1e-9)); // 0.08 - 0.03
      expect(b.inRange, closeTo(0.70, 1e-9));
      expect(b.high, closeTo(0.15, 1e-9)); // 0.22 - 0.07
      expect(b.veryHigh, closeTo(0.07, 1e-9));
      expect(b.sum, closeTo(1.0, 1e-9));
    });

    test('gri is derived from the same bands', () {
      final m = _metrics(
        timeInRange: 0.70,
        timeBelow70: 0.08,
        timeBelow54: 0.03,
        timeAbove180: 0.22,
        timeAbove250: 0.07,
      );
      final b = m.bands;
      final expected = (3.0 * b.veryLow * 100 +
              2.4 * b.low * 100 +
              1.6 * b.veryHigh * 100 +
              0.8 * b.high * 100)
          .clamp(0.0, 100.0);
      expect(m.gri, closeTo(expected, 1e-9));
    });
  });

  group('GlucoseMetrics formulas', () {
    test('GMI and CV match reference formulas', () {
      // All readings at 154 mg/dL → GMI = 3.31 + 0.02392*154 = 6.99%.
      final start = DateTime(2026, 6, 1);
      final samples = List.generate(
        20 * 288, // 20 days of 5-min data
        (i) => CgmSample(
            time: start.add(Duration(minutes: 5 * i)), mgdl: 154),
      );
      final m = const MetricsCalculator().compute(samples);
      expect(m.gmi, closeTo(6.99, 0.02));
      expect(m.cvPercent, closeTo(0.0, 0.01)); // constant → 0 variance
      expect(m.sufficient, isTrue);
    });

    test('TIR counts in-range fraction correctly', () {
      final start = DateTime(2026, 6, 1);
      // Half in range (100), half high (250).
      final samples = <CgmSample>[];
      for (var i = 0; i < 100; i++) {
        samples.add(CgmSample(
            time: start.add(Duration(minutes: 5 * i)),
            mgdl: i.isEven ? 100 : 260));
      }
      final m = const MetricsCalculator().compute(samples);
      expect(m.timeInRange, closeTo(0.5, 0.02));
      expect(m.timeAbove250, closeTo(0.5, 0.02));
    });

    test('insufficient data is flagged below 14 days', () {
      final start = DateTime(2026, 6, 1);
      final samples = List.generate(
        3 * 288,
        (i) => CgmSample(time: start.add(Duration(minutes: 5 * i)), mgdl: 120),
      );
      final m = const MetricsCalculator().compute(samples);
      expect(m.sufficient, isFalse);
    });
  });

  group('Clarke error grid', () {
    const grid = ClarkeErrorGrid();

    test('perfect predictions land in zone A', () {
      final pairs = [
        (reference: 100.0, predicted: 100.0),
        (reference: 200.0, predicted: 205.0),
        (reference: 60.0, predicted: 62.0),
      ];
      final r = grid.evaluate(pairs);
      expect(r.zoneAFraction, 1.0);
      expect(r.abFraction, 1.0);
    });

    test('low-actual/high-predicted is a dangerous zone E miss', () {
      expect(grid.classify(50, 200), ClarkeZone.e);
      expect(grid.classify(200, 60), ClarkeZone.e);
    });

    test('zone B: >20% error but clinically benign', () {
      expect(grid.classify(200, 150), ClarkeZone.b);
      expect(grid.classify(100, 135), ClarkeZone.b);
      expect(grid.classify(250, 320), ClarkeZone.b);
    });

    test('zone C: over-correction regions', () {
      // Upper C: predicted ≥ reference + 110 for in-range reference.
      expect(grid.classify(150, 270), ClarkeZone.c);
      // Lower C: 130–180 reference, predicted ≤ (7/5)·ref − 182.
      expect(grid.classify(160, 40), ClarkeZone.c);
    });

    test('zone D: dangerous failure to detect out-of-range reference', () {
      // High reference read as in-range.
      expect(grid.classify(250, 100), ClarkeZone.d);
      // Low reference read as in-range (outside the ±20% A band).
      expect(grid.classify(65, 130), ClarkeZone.d);
    });

    test('boundary: both ≤ 70 is zone A regardless of relative error', () {
      expect(grid.classify(45, 69), ClarkeZone.a);
    });
  });

  group('HypoDetectionStats', () {
    test('mixed window computes sensitivity and false-alarm rate', () {
      final stats = HypoDetectionStats.fromPairs([
        (reference: 60.0, predicted: 62.0), // TP
        (reference: 65.0, predicted: 100.0), // FN
        (reference: 120.0, predicted: 65.0), // FP
        (reference: 130.0, predicted: 128.0), // TN
        (reference: 140.0, predicted: 150.0), // TN
      ]);
      expect(stats.sensitivity, closeTo(0.5, 1e-9));
      expect(stats.falseAlarmRate, closeTo(1 / 3, 1e-9));
    });

    test('hypo-free window reports null sensitivity, not 0', () {
      final stats = HypoDetectionStats.fromPairs([
        (reference: 120.0, predicted: 118.0),
        (reference: 150.0, predicted: 160.0),
      ]);
      expect(stats.sensitivity, isNull);
      expect(stats.falseAlarmRate, 0.0);
    });

    test('all-lows window reports null false-alarm rate', () {
      final stats = HypoDetectionStats.fromPairs([
        (reference: 55.0, predicted: 60.0),
        (reference: 60.0, predicted: 58.0),
      ]);
      expect(stats.falseAlarmRate, isNull);
      expect(stats.sensitivity, 1.0);
    });
  });
}
