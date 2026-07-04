import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/ml/error_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
            mgdl: i.isEven ? 100 : 250));
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
    });
  });
}
