/// Cheap, safety-relevant invariants that were previously unguarded
/// against sign/clamp/summation bugs:
///  1. Calibrated forecast bands never cross: lower <= point <= upper.
///  2. COB conservation: absorptionRate integrates to the entry's grams.
///  3. Aggregate IOB is monotone-decreasing once the last bolus has landed.
library;

import 'dart:math' as math;

import 'package:bgdude/analytics/carb_math.dart';
import 'package:bgdude/analytics/insulin_math.dart';
import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/dev/sim_data.dart';
import 'package:bgdude/ml/forecast_features.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:bgdude/ml/uncertainty_calibrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('band ordering holds across the sim day under randomized sigmas', () {
    final day = SimulatedDay.generate(now: DateTime(2026, 7, 4, 22), seed: 11);
    final forecaster = Forecaster();
    const cal = UncertaintyCalibrator();
    final rng = math.Random(42); // deterministic

    var checked = 0;
    // Real forecasts every ~2 h across the day, calibrated with random RMSEs
    // (including tiny and huge ones — the clamp/sign edge cases).
    for (var i = 12; i < day.cgm.length; i += 24) {
      final cur = day.cgm[i];
      final state = PredictionState(
        now: cur.time,
        currentMgdl: cur.mgdl,
        recentRocMgdlPerMin: 0,
        boluses: day.boluses,
        basal: day.basal,
        carbs: day.carbs,
        settings: day.settings,
      );
      final raw = forecaster.forecastState(state);
      for (var trial = 0; trial < 20; trial++) {
        final rmse = {
          30: rng.nextDouble() * 120,
          60: rng.nextDouble() * 120,
          120: rng.nextDouble() * 120,
        };
        for (final f in cal.calibrateAll(raw, rmse)) {
          expect(f.lowerMgdl, lessThanOrEqualTo(f.mgdl),
              reason: 'lower crossed the point at ${cur.time} h=${f.horizonMinutes}');
          expect(f.mgdl, lessThanOrEqualTo(f.upperMgdl),
              reason: 'point crossed upper at ${cur.time} h=${f.horizonMinutes}');
          checked++;
        }
      }
    }
    expect(checked, greaterThan(100), reason: 'the sweep must actually run');
  });

  test('COB conservation: absorptionRate integrates to the grams eaten', () {
    const carbs = CarbModel();
    for (final (grams, absorption) in const [
      (30.0, 120.0),
      (75.0, 180.0),
      (15.0, 45.0), // below minAbsorptionMinutes -> clamped internally
      (100.0, 300.0),
    ]) {
      var integral = 0.0;
      const dt = 0.25; // minutes — fine grid so trapezoid error is negligible
      final horizon = math.max(absorption, 120.0) + 30;
      for (var t = 0.0; t < horizon; t += dt) {
        final a = carbs.absorptionRate(t, grams, absorption);
        final b = carbs.absorptionRate(t + dt, grams, absorption);
        integral += (a + b) / 2 * dt;
      }
      expect(integral, closeTo(grams, grams * 0.01),
          reason: '$grams g over $absorption min must be conserved');
    }
  });

  test('COB fraction and absorption rate agree (rate = -d/dt of COB)', () {
    const carbs = CarbModel();
    const grams = 60.0, absorption = 180.0;
    for (var t = 1.0; t < absorption; t += 7) {
      final cobNow = grams * carbs.cobFraction(t, absorption);
      final cobNext = grams * carbs.cobFraction(t + 1, absorption);
      final rate = carbs.absorptionRate(t + 0.5, grams, absorption);
      expect(cobNow - cobNext, closeTo(rate, 0.05),
          reason: 'at t=$t the COB drop must equal the absorption rate');
    }
  });

  test('aggregate IOB is monotone-decreasing after the last bolus', () {
    const iob = IobCalculator();
    final t0 = DateTime(2026, 7, 4, 8);
    final boluses = [
      BolusEvent(time: t0, units: 4),
      BolusEvent(time: t0.add(const Duration(minutes: 50)), units: 1.5),
      BolusEvent(time: t0.add(const Duration(minutes: 130)), units: 2.25),
    ];
    final last = boluses.last.time;
    var prev = double.infinity;
    for (var m = 0; m <= 8 * 60; m += 5) {
      final at = last.add(Duration(minutes: m));
      final units = iob.fromBoluses(boluses, at).units;
      expect(units, lessThanOrEqualTo(prev + 1e-9),
          reason: 'IOB rose at +$m min after the last bolus');
      expect(units, greaterThanOrEqualTo(0));
      prev = units;
    }
    // And it fully decays once every DIA has elapsed.
    expect(prev, closeTo(0, 1e-9));
  });
}
