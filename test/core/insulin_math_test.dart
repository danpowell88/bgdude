import 'package:bgdude/analytics/insulin_math.dart';
import 'package:bgdude/core/samples.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Exponential IOB curve', () {
    const model = InsulinModel.rapidActing; // 6h DIA, 75-min peak

    test('is 1.0 at delivery and 0.0 after duration', () {
      expect(model.iobFraction(0), 1.0);
      expect(model.iobFraction(360), 0.0);
      expect(model.iobFraction(400), 0.0);
    });

    test('pins hand-computed curve values (TASK-160)', () {
      // Model-independent anchors for DIA=360 / peak=75 (LoopKit exponential):
      //   tau = 75*(1-75/360)/(1-2*75/360) = 101.7857
      //   a = 2*tau/360 = 0.565476, S = 1/(1-a+(1+a)e^{-360/tau})
      //   iob(75) = 0.694263, iob(180) = 0.208171 (computed outside the codebase).
      expect(model.iobFraction(75), closeTo(0.6943, 5e-4));
      expect(model.iobFraction(180), closeTo(0.2082, 5e-4));
    });

    test('activity is maximal exactly at t = peak (TASK-160)', () {
      final atPeak = model.activity(75);
      expect(atPeak, greaterThan(model.activity(74)));
      expect(atPeak, greaterThan(model.activity(76)));
    });

    test('decreases monotonically over the duration', () {
      var prev = 1.0;
      for (var t = 5.0; t <= 360; t += 5) {
        final f = model.iobFraction(t);
        expect(f, lessThanOrEqualTo(prev + 1e-9),
            reason: 'IOB should not increase at t=$t');
        expect(f, inInclusiveRange(-1e-6, 1.0));
        prev = f;
      }
    });

    test('activity integrates to approximately 1 over the duration', () {
      var area = 0.0;
      const dt = 1.0;
      for (var t = 0.0; t < 360; t += dt) {
        area += model.activity(t + dt / 2) * dt;
      }
      expect(area, closeTo(1.0, 0.05));
    });

    test('activity peaks near the configured peak time', () {
      var bestT = 0.0;
      var best = 0.0;
      for (var t = 1.0; t < 360; t += 1) {
        final a = model.activity(t);
        if (a > best) {
          best = a;
          bestT = t;
        }
      }
      expect(bestT, closeTo(75, 20));
    });
  });

  group('IobCalculator', () {
    test('reports full units immediately after a bolus', () {
      const calc = IobCalculator();
      final now = DateTime(2026, 7, 4, 12);
      final boluses = [BolusEvent(time: now, units: 5)];
      final iob = calc.fromBoluses(boluses, now);
      expect(iob.units, closeTo(5.0, 1e-6));
    });

    test('decays a bolus toward zero after DIA', () {
      const calc = IobCalculator();
      final t0 = DateTime(2026, 7, 4, 6);
      final boluses = [BolusEvent(time: t0, units: 5)];
      final later = t0.add(const Duration(hours: 6, minutes: 5));
      final iob = calc.fromBoluses(boluses, later);
      expect(iob.units, closeTo(0.0, 1e-6));
    });

    test('half of a bolus roughly remains around the peak window', () {
      const calc = IobCalculator();
      final t0 = DateTime(2026, 7, 4, 6);
      final boluses = [BolusEvent(time: t0, units: 4)];
      final atPeak = t0.add(const Duration(minutes: 75));
      final iob = calc.fromBoluses(boluses, atPeak);
      // At the activity peak a meaningful fraction is used but most still on board.
      expect(iob.units, inInclusiveRange(1.5, 3.5));
    });
  });
}
