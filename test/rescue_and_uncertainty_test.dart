import 'package:bgdude/analytics/rescue_carbs.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:bgdude/ml/uncertainty_calibrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RescueCarbCalculator', () {
    // ISF 50 mg/dL/U, CR 10 g/U → CSF 5 mg/dL per gram.
    RescueCarbAdvice advise({
      required double bg,
      double iob = 0,
      double? nadir,
    }) =>
        const RescueCarbCalculator().advise(
          currentMgdl: bg,
          targetMgdl: 100,
          isf: 50,
          carbRatio: 10,
          iobUnits: iob,
          predictedNadirMgdl: nadir,
        );

    test('no rescue when comfortably above target and no low predicted', () {
      final a = advise(bg: 140);
      expect(a.needed, isFalse);
    });

    test('suggests carbs to close the gap toward target', () {
      // Predicted nadir 65 (below 70) → the 15g rescue floor applies.
      final a = advise(bg: 95, nadir: 65);
      expect(a.needed, isTrue);
      expect(a.grams, greaterThanOrEqualTo(15));
    });

    test('urgent flag and 15g floor when actually low', () {
      final a = advise(bg: 52);
      expect(a.urgent, isTrue);
      expect(a.grams, greaterThanOrEqualTo(15));
    });

    test('accounts for IOB pulling further down', () {
      final withIob = advise(bg: 95, iob: 2);
      final without = advise(bg: 95, iob: 0);
      expect(withIob.grams, greaterThanOrEqualTo(without.grams));
    });

    test('caps over-treatment', () {
      final a = advise(bg: 45, nadir: 40, iob: 5);
      expect(a.grams, lessThanOrEqualTo(45));
    });
  });

  group('UncertaintyCalibrator', () {
    const cal = UncertaintyCalibrator(minSamples: 3);

    test('computes per-horizon RMSE and ignores thin horizons', () {
      final pairs = [
        (horizon: 30, predicted: 100.0, actual: 110.0),
        (horizon: 30, predicted: 100.0, actual: 90.0),
        (horizon: 30, predicted: 100.0, actual: 110.0),
        (horizon: 60, predicted: 100.0, actual: 100.0), // only 1 → ignored
      ];
      final rmse = cal.perHorizonRmse(pairs);
      expect(rmse[30], closeTo(10.0, 0.01));
      expect(rmse.containsKey(60), isFalse);
    });

    test('widens the cone to at least recent RMSE', () {
      final f = HorizonForecast(
          horizonMinutes: 30, mgdl: 120, lowerMgdl: 110, upperMgdl: 130);
      final wide = cal.calibrate(f, {30: 40.0});
      // sigma becomes ~40 → interval ±1.64*40 ≈ ±66.
      expect(wide.upperMgdl - wide.mgdl, greaterThan(50));
      expect(wide.lowerMgdl, lessThan(f.lowerMgdl));
    });

    test('leaves a forecast unchanged when no recent error for its horizon', () {
      final f = HorizonForecast(
          horizonMinutes: 30, mgdl: 120, lowerMgdl: 110, upperMgdl: 130);
      expect(cal.calibrate(f, const {}).upperMgdl, f.upperMgdl);
    });
  });
}
