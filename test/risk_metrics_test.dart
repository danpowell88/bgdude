import 'dart:math' as math;

import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/core/samples.dart';
import 'package:flutter_test/flutter_test.dart';

List<CgmSample> _at(double mgdl, int count) => [
      for (var i = 0; i < count; i++)
        CgmSample(time: DateTime(2026, 7, 4, 0, i * 5), mgdl: mgdl),
    ];

/// Reference LBGI/HBGI contribution of a single reading (Kovatchev).
double _risk(double bg, {required bool low}) {
  final f = 1.509 * (math.pow(math.log(bg), 1.084) - 5.381);
  if (low && f < 0) return 10 * f * f;
  if (!low && f > 0) return 10 * f * f;
  return 0;
}

void main() {
  const calc = MetricsCalculator();

  group('GRI', () {
    test('is 0 for an all-in-range trace', () {
      final m = calc.compute(_at(120, 50));
      expect(m.gri, 0);
    });

    test('weights hypos ~3.75× the equivalent hyperglycaemia band', () {
      // GRI = 3.0·VLow + 2.4·Low + 1.6·VHigh + 0.8·High.
      // All very-low (<54): GRI = 3.0 × 100 → clamped to 100.
      expect(calc.compute(_at(45, 50)).gri, 100);
      // All in 180–250 (High band): GRI = 0.8 × 100 = 80.
      expect(calc.compute(_at(200, 50)).gri, closeTo(80, 1e-6));
      // All very-high (>250): GRI = 1.6 × 100 → clamped to 100.
      expect(calc.compute(_at(300, 50)).gri, 100);
    });

    test('a modest low fraction contributes its weighted share', () {
      // 10% of readings <54, rest in range → VLow=10 → GRI = 30.
      final cgm = [..._at(45, 5), ..._at(120, 45)];
      expect(calc.compute(cgm).gri, closeTo(30, 1e-6));
    });
  });

  group('LBGI / HBGI', () {
    test('match the Kovatchev formula for a steady low and high', () {
      final low = calc.compute(_at(50, 40));
      expect(low.lbgi, closeTo(_risk(50, low: true), 1e-6));
      expect(low.hbgi, 0);

      final high = calc.compute(_at(300, 40));
      expect(high.hbgi, closeTo(_risk(300, low: false), 1e-6));
      expect(high.lbgi, 0);
    });

    test('an in-range trace has near-zero indices', () {
      final m = calc.compute(_at(112, 40)); // ~112 is close to the risk-neutral point
      expect(m.lbgi, lessThan(1.0));
      expect(m.hbgi, lessThan(1.0));
    });

    test('empty metrics are zero', () {
      final m = calc.compute(const []);
      expect(m.gri, 0);
      expect(m.lbgi, 0);
      expect(m.hbgi, 0);
    });
  });
}
