/// Online recalibration of the forecast prediction interval from recent *live* error.
///
/// The residual model's sigma comes from training data; but real recent accuracy drifts
/// (a new sensor, an off day). This widens (never narrows below the model's own) the
/// cone using the observed per-horizon RMSE over the last couple of weeks of reconciled
/// predictions, so the band reflects how the forecast is actually doing right now.
library;

import 'dart:math' as math;

import 'forecaster.dart';

class UncertaintyCalibrator {
  const UncertaintyCalibrator({this.minSamples = 20});

  /// Below this many scored pairs for a horizon, we don't trust the live estimate.
  final int minSamples;

  /// Per-horizon RMSE (mg/dL) from scored (predicted, actual) pairs.
  Map<int, double> perHorizonRmse(
    List<({int horizon, double predicted, double actual})> pairs,
  ) {
    final byH = <int, List<double>>{};
    for (final p in pairs) {
      (byH[p.horizon] ??= <double>[]).add(p.predicted - p.actual);
    }
    final out = <int, double>{};
    byH.forEach((h, errs) {
      if (errs.length < minSamples) return;
      var sq = 0.0;
      for (final e in errs) {
        sq += e * e;
      }
      out[h] = math.sqrt(sq / errs.length);
    });
    return out;
  }

  /// Widen [f]'s interval so its sigma is at least the recent live RMSE for its horizon.
  HorizonForecast calibrate(HorizonForecast f, Map<int, double> recentRmse) {
    final recent = recentRmse[f.horizonMinutes];
    if (recent == null) return f;
    final modelSigma = (f.upperMgdl - f.mgdl) / 1.64;
    final sigma = math.max(modelSigma, recent);
    return HorizonForecast(
      horizonMinutes: f.horizonMinutes,
      mgdl: f.mgdl,
      lowerMgdl: (f.mgdl - 1.64 * sigma).clamp(39.0, 400.0),
      upperMgdl: (f.mgdl + 1.64 * sigma).clamp(39.0, 400.0),
    );
  }

  List<HorizonForecast> calibrateAll(
          List<HorizonForecast> forecasts, Map<int, double> recentRmse) =>
      [for (final f in forecasts) calibrate(f, recentRmse)];
}
