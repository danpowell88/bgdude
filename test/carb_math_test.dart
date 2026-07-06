import 'package:bgdude/analytics/carb_math.dart';
import 'package:bgdude/core/samples.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const model = CarbModel();

  group('cobFraction (symmetric bilinear)', () {
    test('1.0 at or before the entry, 0.0 at/after absorption ends', () {
      expect(model.cobFraction(0, 120), 1.0);
      expect(model.cobFraction(-5, 120), 1.0);
      expect(model.cobFraction(120, 120), 0.0);
      expect(model.cobFraction(200, 120), 0.0);
    });

    test('exactly half remaining at the midpoint', () {
      // Symmetric triangle → 50% absorbed at td/2.
      expect(model.cobFraction(60, 120), closeTo(0.5, 1e-9));
    });

    test('monotonically decreasing over the window', () {
      double prev = 1.0;
      for (var t = 1; t < 120; t += 5) {
        final v = model.cobFraction(t.toDouble(), 120);
        expect(v, lessThanOrEqualTo(prev + 1e-12));
        prev = v;
      }
    });

    test('absorption time is floored at minAbsorptionMinutes (30)', () {
      // A 10-min declared time is clamped to 30, so at t=15 it is at the midpoint (0.5),
      // not already fully absorbed.
      expect(model.cobFraction(15, 10), closeTo(0.5, 1e-9));
      expect(model.cobFraction(15, 30), closeTo(0.5, 1e-9));
    });
  });

  test('cob sums entries and ignores future ones', () {
    final now = DateTime(2026, 7, 4, 12);
    final entries = [
      CarbEntry(time: now.subtract(const Duration(minutes: 60)), grams: 40, absorptionMinutes: 120),
      CarbEntry(time: now.add(const Duration(minutes: 10)), grams: 30, absorptionMinutes: 120), // future
    ];
    // 40 g at its midpoint → ~20 g on board; the future entry contributes nothing.
    expect(model.cob(entries, now), closeTo(20.0, 0.5));
  });

  test('absorptionRate is a triangle: 0 at the edges, peak 2*grams/td at the middle', () {
    expect(model.absorptionRate(0, 60, 120), 0.0);
    expect(model.absorptionRate(120, 60, 120), 0.0);
    // Peak rate at t=60 = 2*60/120 = 1.0 g/min.
    expect(model.absorptionRate(60, 60, 120), closeTo(1.0, 1e-9));
  });

  test('carbSensitivityFactor = ISF / carb ratio', () {
    expect(carbSensitivityFactor(isf: 50, carbRatio: 10), closeTo(5.0, 1e-9));
  });
}
