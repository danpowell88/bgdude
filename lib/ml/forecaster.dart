/// Blood-glucose forecaster.
///
/// The forecast is always `deterministic baseline + learned residual`. The baseline is
/// the physiological what-if engine (`GlucosePredictor`); the residual is a small
/// learned correction that captures the individual's systematic deviations from the
/// baseline (e.g. dawn phenomenon, consistent post-meal overshoot). The residual model
/// is optional — until it exists / earns trust, the forecast is the pure baseline.
///
/// The neural residual (a <100k-param GRU/TCN) runs via LiteRT on device and is
/// fine-tuned overnight through training signatures. That native path is wrapped behind
/// [ResidualModel] so the rest of the app is agnostic to it and the deterministic path
/// stays fully testable.
library;

import '../analytics/predictor.dart';
import '../core/units.dart';

/// Forecast at a single horizon.
class HorizonForecast {
  const HorizonForecast({
    required this.horizonMinutes,
    required this.mgdl,
    required this.lowerMgdl,
    required this.upperMgdl,
  });

  final int horizonMinutes;
  final double mgdl;

  /// Prediction interval (from residual-model uncertainty; falls back to a widening
  /// band with horizon for the deterministic-only case).
  final double lowerMgdl;
  final double upperMgdl;

  double get intervalWidth => upperMgdl - lowerMgdl;
}

/// Interface for the learned residual model. Implemented natively (LiteRT) in
/// `residual_model_litert.dart`; a no-op default keeps the app deterministic-only.
abstract interface class ResidualModel {
  /// Residual (mg/dL) to add to the baseline prediction at [horizonMinutes], plus a
  /// 1-sigma uncertainty. Returns (0, wideSigma) when untrained.
  ({double residual, double sigma}) correct({
    required List<double> features,
    required int horizonMinutes,
  });

  bool get isTrained;
}

/// Deterministic-only residual: no correction, uncertainty widens with horizon.
class NoResidualModel implements ResidualModel {
  const NoResidualModel();

  @override
  bool get isTrained => false;

  @override
  ({double residual, double sigma}) correct({
    required List<double> features,
    required int horizonMinutes,
  }) {
    // Empirical widening: ~ half an mmol at 30 min growing to ~2.5 mmol at 120 min.
    final sigma = 9 + horizonMinutes * 0.30;
    return (residual: 0.0, sigma: sigma);
  }
}

class Forecaster {
  Forecaster({
    GlucosePredictor? predictor,
    ResidualModel? residual,
    this.horizons = const [30, 60, 120],
  })  : _predictor = predictor ?? GlucosePredictor(),
        _residual = residual ?? const NoResidualModel();

  final GlucosePredictor _predictor;
  final ResidualModel _residual;
  final List<int> horizons;

  List<HorizonForecast> forecast(
    PredictionState state, {
    List<double> Function(int horizon)? featureBuilder,
  }) {
    final line = _predictor.predict(state);
    final out = <HorizonForecast>[];
    for (final h in horizons) {
      final target = state.now.add(Duration(minutes: h));
      final baseline = _valueAt(line, target);
      final feats = featureBuilder?.call(h) ?? const <double>[];
      final c = _residual.correct(features: feats, horizonMinutes: h);
      final mgdl = (baseline + c.residual).clamp(39.0, 400.0);
      // 90% interval ≈ ±1.64σ.
      out.add(HorizonForecast(
        horizonMinutes: h,
        mgdl: mgdl,
        lowerMgdl: (mgdl - 1.64 * c.sigma).clamp(39.0, 400.0),
        upperMgdl: (mgdl + 1.64 * c.sigma).clamp(39.0, 400.0),
      ));
    }
    return out;
  }

  /// Whether the forecast is currently trustworthy enough to headline in the simple UI.
  bool get residualTrained => _residual.isTrained;

  static double _valueAt(PredictionLine line, DateTime t) {
    // Nearest point (the predictor's step grid is fine-grained).
    var best = line.points.first;
    var bestDelta = (best.time.difference(t)).inSeconds.abs();
    for (final p in line.points) {
      final d = p.time.difference(t).inSeconds.abs();
      if (d < bestDelta) {
        best = p;
        bestDelta = d;
      }
    }
    return best.mgdl;
  }
}

extension HorizonForecastDisplay on HorizonForecast {
  String display(GlucoseUnit unit) =>
      '${Mgdl(mgdl).display(unit)} (${Mgdl(lowerMgdl).display(unit)}–${Mgdl(upperMgdl).display(unit)})';
}
