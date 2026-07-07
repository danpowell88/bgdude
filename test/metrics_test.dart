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

    test('gri pins to a hand-calculated literal, not re-derived weights', () {
      // TASK-160: the old expectation re-derived the Klonoff weights from the
      // production code, proving nothing. Hand calculation:
      //   VLow 3% -> 3.0*3 = 9;  Low 5% -> 2.4*5 = 12;
      //   VHigh 7% -> 1.6*7 = 11.2;  High 15% -> 0.8*15 = 12.
      //   GRI = 9 + 12 + 11.2 + 12 = 44.2
      final m = _metrics(
        timeInRange: 0.70,
        timeBelow70: 0.08,
        timeBelow54: 0.03,
        timeAbove180: 0.22,
        timeAbove250: 0.07,
      );
      expect(m.gri, closeTo(44.2, 1e-9));
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

    test('a CGM gap lowers active fraction/sufficiency but never corrupts TIR '
        '(TASK-94 AC#1)', () {
      final start = DateTime(2026, 6, 1);
      // 12 real days of readings spread across a 19-day span (an 8-day sensor
      // gap in the middle) — every reading in range.
      final samples = <CgmSample>[
        for (var day = 0; day < 10; day++)
          for (var i = 0; i < 288; i++)
            CgmSample(
                time: start
                    .add(Duration(days: day))
                    .add(Duration(minutes: 5 * i)),
                mgdl: 100),
        for (var day = 18; day < 20; day++)
          for (var i = 0; i < 288; i++)
            CgmSample(
                time: start
                    .add(Duration(days: day))
                    .add(Duration(minutes: 5 * i)),
                mgdl: 100),
      ];
      final m = const MetricsCalculator().compute(samples);

      // The gap shows up as reduced coverage, not a skewed ratio: every present
      // reading is in range, so TIR stays exactly 1.0 regardless of the gap.
      expect(m.timeInRange, 1.0);
      expect(m.activeFraction, lessThan(0.70),
          reason: 'the 8-day gap should push active time below the 70% floor');
      expect(m.sufficient, isFalse,
          reason: 'low active fraction must flag the window as insufficient, '
              'not silently report a clean TIR');
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

    test('pins the published boundary segments (TASK-160)', () {
      // Upper-C ceiling: pred >= ref+110 applies only while ref <= 290.
      expect(grid.classify(290, 400), ClarkeZone.c);
      expect(grid.classify(291, 401), ClarkeZone.b);
      // Zone-D onset for missed highs: ref >= 240 with an in-range prediction.
      expect(grid.classify(240, 100), ClarkeZone.d);
      expect(grid.classify(239, 100), ClarkeZone.b);
      // Lower-C segment (pred <= (7/5)*ref - 182 within ref 130..180):
      // at ref=170 the boundary is pred = 56 (straddled here rather than hit
      // exactly — 7/5 is not exactly representable in binary floating point).
      expect(grid.classify(170, 55.9), ClarkeZone.c);
      expect(grid.classify(170, 56.1), ClarkeZone.b);
      // Exact +/-20% zone-A edges.
      expect(grid.classify(100, 120), ClarkeZone.a);
      expect(grid.classify(100, 121), ClarkeZone.b);
      expect(grid.classify(100, 80), ClarkeZone.a);
      expect(grid.classify(100, 79), ClarkeZone.b);
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

  group('CV boundary and AGP percentile pins (TASK-160)', () {
    List<CgmSample> alternating(double lo, double hi, {int count = 40}) => [
          for (var i = 0; i < count; i++)
            CgmSample(
                time: DateTime(2026, 7, 4).add(Duration(minutes: 5 * i)),
                mgdl: i.isEven ? lo : hi),
        ];

    test('an alternating 100/200 trace pins CV to 33.3%', () {
      // mean 150, population SD 50 -> CV = 50/150 = 33.33%.
      final m = const MetricsCalculator().compute(alternating(100, 200));
      expect(m.cvPercent, closeTo(33.333, 0.01));
      expect(m.variabilityHigh, isFalse);
    });

    test('variabilityHigh flips exactly at the consensus CV 36%', () {
      // 64.1/135.9: mean 100, SD 35.9 -> CV 35.9% (stable).
      final below = const MetricsCalculator().compute(alternating(64.1, 135.9));
      expect(below.cvPercent, closeTo(35.9, 0.01));
      expect(below.variabilityHigh, isFalse);
      // 64/136: mean 100, SD 36 -> CV 36.0% (labile).
      final at = const MetricsCalculator().compute(alternating(64, 136));
      expect(at.cvPercent, closeTo(36.0, 0.01));
      expect(at.variabilityHigh, isTrue);
    });

    test('AGP percentile is type-7: [10,20,30,40] p25 = 17.5', () {
      // Four readings in one hour bucket; p25 rank = 0.25*(4-1) = 0.75
      // -> 10 + 0.75*(20-10) = 17.5. Median rank 1.5 -> 25.
      final t0 = DateTime(2026, 7, 4, 9, 0);
      final samples = [
        for (final (i, v) in const [10.0, 20.0, 30.0, 40.0].indexed)
          CgmSample(time: t0.add(Duration(minutes: 5 * i)), mgdl: v),
      ];
      final buckets = const AgpCalculator().compute(samples);
      expect(buckets, hasLength(1));
      expect(buckets.single.p25, closeTo(17.5, 1e-9));
      expect(buckets.single.median, closeTo(25.0, 1e-9));
      expect(buckets.single.p75, closeTo(32.5, 1e-9));
    });

    test('a thin AGP bucket is flagged sparse', () {
      final t0 = DateTime(2026, 7, 4, 9, 0);
      final thin = const AgpCalculator().compute([
        for (var i = 0; i < AgpBucket.minCountForBands - 1; i++)
          CgmSample(time: t0.add(Duration(minutes: i)), mgdl: 100),
      ]);
      expect(thin.single.sparse, isTrue);
      final dense = const AgpCalculator().compute([
        for (var i = 0; i < AgpBucket.minCountForBands; i++)
          CgmSample(time: t0.add(Duration(minutes: i)), mgdl: 100),
      ]);
      expect(dense.single.sparse, isFalse);
    });
  });
}
