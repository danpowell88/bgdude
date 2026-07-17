import 'package:bgdude/ml/forecaster.dart';
import 'package:bgdude/ml/threshold_duration.dart';
import 'package:flutter_test/flutter_test.dart';

HorizonForecast _f(int h, double mgdl, {double? lower, double? upper}) =>
    HorizonForecast(
      horizonMinutes: h,
      mgdl: mgdl,
      lowerMgdl: lower ?? mgdl,
      upperMgdl: upper ?? mgdl,
    );

void main() {
  const estimator = ThresholdDurationEstimator();

  group('minutesBelow', () {
    test('a trajectory that stays below threshold the whole horizon counts '
        'the full span', () {
      final forecasts = [_f(30, 60), _f(60, 55), _f(120, 50)];
      final d = estimator.minutesBelow(forecasts, 65, 70);
      expect(d.pointMinutes, 120);
      expect(d.isPredicted, isTrue);
    });

    test('a trajectory that never crosses the threshold predicts zero', () {
      final forecasts = [_f(30, 120), _f(60, 130), _f(120, 140)];
      final d = estimator.minutesBelow(forecasts, 110, 70);
      expect(d.pointMinutes, 0);
      expect(d.isPredicted, isFalse);
    });

    test('interpolates the exact crossing point within a segment', () {
      // Starts at 100 (above 70), falls linearly to 40 at +30min -- crosses
      // 70 at (100-70)/(100-40) = 0.5 of the way, i.e. +15min. Then stays
      // below threshold through the rest of the horizon (60, 120 also < 70).
      final forecasts = [_f(30, 40), _f(60, 30), _f(120, 20)];
      final d = estimator.minutesBelow(forecasts, 100, 70);
      // Below-threshold span: (+15..+30) = 15, plus the full 30->60 (30) and
      // 60->120 (60) segments = 15 + 30 + 60 = 105.
      expect(d.pointMinutes, 105);
    });

    test(
        'confidentMinutes uses the upper (less severe) bound and is never '
        'longer than pointMinutes', () {
      // Point trajectory dips below 70 the whole horizon, but the upper bound
      // stays at/above 70 until +60min -- so the CONFIDENT low is shorter.
      final forecasts = [
        _f(30, 60, lower: 50, upper: 75),
        _f(60, 55, lower: 45, upper: 68),
        _f(120, 50, lower: 40, upper: 60),
      ];
      final d = estimator.minutesBelow(forecasts, 65, 70);
      expect(d.pointMinutes, 120);
      expect(d.confidentMinutes, lessThan(d.pointMinutes));
    });

    test('empty forecast list predicts zero, does not throw', () {
      expect(() => estimator.minutesBelow(const [], 65, 70), returnsNormally);
      expect(estimator.minutesBelow(const [], 65, 70).pointMinutes, 0);
    });
  });

  group('minutesAbove', () {
    test('a trajectory that stays above threshold the whole horizon counts '
        'the full span', () {
      final forecasts = [_f(30, 190), _f(60, 200), _f(120, 210)];
      final d = estimator.minutesAbove(forecasts, 185, 180);
      expect(d.pointMinutes, 120);
      expect(d.isPredicted, isTrue);
    });

    test('a trajectory that never exceeds the threshold predicts zero', () {
      final forecasts = [_f(30, 140), _f(60, 150), _f(120, 160)];
      final d = estimator.minutesAbove(forecasts, 120, 180);
      expect(d.pointMinutes, 0);
    });

    test(
        'confidentMinutes uses the lower (less severe) bound and is never '
        'longer than pointMinutes', () {
      final forecasts = [
        _f(30, 190, lower: 175, upper: 200),
        _f(60, 200, lower: 185, upper: 210),
        _f(120, 210, lower: 195, upper: 220),
      ];
      final d = estimator.minutesAbove(forecasts, 185, 180);
      expect(d.pointMinutes, 120);
      expect(d.confidentMinutes, lessThan(d.pointMinutes));
    });
  });
}
