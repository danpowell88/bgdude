import 'package:bgdude/analytics/metrics.dart';
import 'package:bgdude/core/samples.dart';
import 'package:flutter_test/flutter_test.dart';

List<CgmSample> _at(double mgdl, int count) => [
      for (var i = 0; i < count; i++)
        CgmSample(time: DateTime(2026, 7, 4, 0, i * 5), mgdl: mgdl),
    ];

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

    test('a mixed trace pins GRI to a hand-calculated literal (TASK-160)', () {
      // 100 readings: 5 at 50 (<54), 5 at 60 (54-69), 60 at 120 (in range),
      // 20 at 200 (181-250), 10 at 300 (>250).
      // GRI = 3.0*5 + 2.4*5 + 1.6*10 + 0.8*20 = 15 + 12 + 16 + 16 = 59.
      final cgm = [
        ..._at(50, 5),
        ..._at(60, 5),
        ..._at(120, 60),
        ..._at(200, 20),
        ..._at(300, 10),
      ];
      expect(calc.compute(cgm).gri, closeTo(59.0, 1e-6));
    });
  });

  group('LBGI / HBGI', () {
    // TASK-160: hand-computed, MODEL-INDEPENDENT anchors (the old test copied the
    // production expression verbatim and compared it to itself, so a constant
    // regression like 1.084 -> 1.026 passed). Derivations:
    //   f(bg) = 1.509*(ln(bg)^1.084 - 5.381); risk = 10*f^2 on the matching side.
    //   f(112.5) = 1.509*(ln(112.5)^1.084 - 5.381) = -0.000288  (the zero point)
    //   LBGI at steady 50: ln(50)=3.9120, 3.9120^1.084=4.38375,
    //     f = 1.509*(4.38375-5.381) = -1.50493, 10*f^2 = 22.5004
    test('steady BG 50 pins LBGI to the hand-computed 22.5', () {
      final low = calc.compute(_at(50, 40));
      expect(low.lbgi, closeTo(22.5004, 0.01));
      expect(low.hbgi, 0);
    });

    test('the Kovatchev risk function is zero at BG 112.5', () {
      // Both indices vanish when every reading sits on the risk-neutral point.
      final m = calc.compute(_at(112.5, 40));
      expect(m.lbgi, closeTo(0, 1e-4));
      expect(m.hbgi, closeTo(0, 1e-4));
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
