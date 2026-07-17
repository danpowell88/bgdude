/// Predicted minutes spent below/above a glucose threshold (TASK-143), derived
/// from the forecaster's horizon grid rather than a single point forecast --
/// "predicted low for ~25 min" is the clinically actionable quantity (treat-now
/// vs ride-it-out) that a lone point estimate can't answer.
///
/// The trajectory between horizon grid points (now, then each [HorizonForecast])
/// is approximated by straight-line interpolation. The horizons are widely
/// spaced (30/60/120 min), so this is a coarse but honest approximation, not a
/// re-run of the physiological model at finer resolution.
library;

import 'forecaster.dart';

/// Predicted duration below/above a threshold, from two angles: the point
/// (best-estimate) trajectory, and the LESS SEVERE side of the prediction
/// interval -- the upper bound for a low, the lower bound for a high. If even
/// that more optimistic bound still crosses the threshold, the excursion is
/// one you can be more confident about; [confidentMinutes] is therefore
/// never longer than [pointMinutes].
class ThresholdDuration {
  const ThresholdDuration({
    required this.pointMinutes,
    required this.confidentMinutes,
  });

  final int pointMinutes;
  final int confidentMinutes;

  /// Whether the point trajectory predicts any time on the threshold's side
  /// at all.
  bool get isPredicted => pointMinutes > 0;
}

class ThresholdDurationEstimator {
  const ThresholdDurationEstimator();

  /// Predicted minutes below [thresholdMgdl] (e.g. the low line). The
  /// confident estimate uses the interval's UPPER (less severe) bound -- if
  /// even the more optimistic reading is still predicted low, that's the
  /// duration you can count on.
  ThresholdDuration minutesBelow(
    List<HorizonForecast> forecasts,
    double currentMgdl,
    double thresholdMgdl,
  ) =>
      _estimate(
        forecasts,
        currentMgdl,
        thresholdMgdl,
        confidentBoundOf: (f) => f.upperMgdl,
        below: true,
      );

  /// Predicted minutes above [thresholdMgdl] (e.g. the high line). The
  /// confident estimate uses the interval's LOWER (less severe) bound.
  ThresholdDuration minutesAbove(
    List<HorizonForecast> forecasts,
    double currentMgdl,
    double thresholdMgdl,
  ) =>
      _estimate(
        forecasts,
        currentMgdl,
        thresholdMgdl,
        confidentBoundOf: (f) => f.lowerMgdl,
        below: false,
      );

  ThresholdDuration _estimate(
    List<HorizonForecast> forecasts,
    double currentMgdl,
    double thresholdMgdl, {
    required double Function(HorizonForecast) confidentBoundOf,
    required bool below,
  }) {
    if (forecasts.isEmpty) {
      return const ThresholdDuration(pointMinutes: 0, confidentMinutes: 0);
    }
    final sorted = [...forecasts]
      ..sort((a, b) => a.horizonMinutes.compareTo(b.horizonMinutes));
    return ThresholdDuration(
      pointMinutes: _crossingMinutes(sorted, currentMgdl, thresholdMgdl,
          valueOf: (f) => f.mgdl, below: below),
      confidentMinutes: _crossingMinutes(sorted, currentMgdl, thresholdMgdl,
          valueOf: confidentBoundOf, below: below),
    );
  }

  /// Piecewise-linear interpolation across (0, currentMgdl), then each sorted
  /// forecast's (horizonMinutes, value) -- summing the minutes each segment
  /// spends on the below/above side of [thresholdMgdl], interpolating the
  /// exact crossing point within a segment that straddles the threshold.
  int _crossingMinutes(
    List<HorizonForecast> sorted,
    double currentMgdl,
    double thresholdMgdl, {
    required double Function(HorizonForecast) valueOf,
    required bool below,
  }) {
    bool isSide(double v) => below ? v < thresholdMgdl : v > thresholdMgdl;

    var total = 0.0;
    var prevT = 0.0;
    var prevV = currentMgdl;
    for (final f in sorted) {
      final t = f.horizonMinutes.toDouble();
      final v = valueOf(f);
      final dt = t - prevT;
      if (dt <= 0) {
        prevT = t;
        prevV = v;
        continue;
      }
      final prevSide = isSide(prevV);
      final curSide = isSide(v);
      if (prevSide && curSide) {
        total += dt;
      } else if (prevSide != curSide) {
        final denom = v - prevV;
        final frac =
            denom == 0 ? 0.0 : ((thresholdMgdl - prevV) / denom).clamp(0.0, 1.0);
        total += prevSide ? dt * frac : dt * (1 - frac);
      }
      prevT = t;
      prevV = v;
    }
    return total.round();
  }
}
