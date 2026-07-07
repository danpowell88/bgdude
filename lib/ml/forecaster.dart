/// Blood-glucose forecaster.
///
/// The forecast is always `deterministic baseline + learned residual`. The baseline is
/// the physiological what-if engine (`GlucosePredictor`); the residual is a small
/// learned correction that captures the individual's systematic deviations from the
/// baseline (e.g. dawn phenomenon, consistent post-meal overshoot). The residual model
/// is optional — until it exists / earns trust, the forecast is the pure baseline.
///
/// The learned residual is the pure-Dart per-horizon GBM (`ResidualGbmModel`): fully
/// on-device, deterministic, auditable, and retrained from the feedback pipeline. It
/// sits behind [ResidualModel] so the deterministic path stays fully testable.
library;

import '../analytics/predictor.dart';
import '../core/units.dart';

/// z-value for the ~90% prediction interval (±1.64σ), shared by every band builder.
const double kForecastZ90 = 1.64;

/// Widening fallback 1-sigma uncertainty for when no learned residual model is
/// available at [horizonMinutes] — deterministic-only forecasts (untrained
/// horizons, or a missing per-horizon sigma) all use this same empirical curve
/// (TASK-136): ~half an mmol at 30 min growing to ~2.5 mmol at 120 min. Was
/// copy-pasted across three call sites; kept in one place next to [kForecastZ90]
/// since both are safety-relevant band-width constants.
double fallbackSigma(int horizonMinutes) => 9 + horizonMinutes * 0.30;

/// Forecast at a single horizon.
class HorizonForecast {
  /// Values arrive as raw doubles from the model math and are CARRIED as
  /// [Mgdl] (TASK-119); non-const because the wrapping initializer isn't a
  /// constant expression.
  HorizonForecast({
    required this.horizonMinutes,
    required double mgdl,
    required double lowerMgdl,
    required double upperMgdl,
  })  : mgdl = Mgdl(mgdl),
        lowerMgdl = Mgdl(lowerMgdl),
        upperMgdl = Mgdl(upperMgdl);

  final int horizonMinutes;
  final Mgdl mgdl;

  /// Prediction interval (from residual-model uncertainty; falls back to a widening
  /// band with horizon for the deterministic-only case).
  final Mgdl lowerMgdl;
  final Mgdl upperMgdl;

  double get intervalWidth => upperMgdl - lowerMgdl;
}

/// Interface for the learned residual model. Implemented by the pure-Dart
/// `ResidualGbmModel`; a no-op default keeps the app deterministic-only.
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
    return (residual: 0.0, sigma: fallbackSigma(horizonMinutes));
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
      out.add(HorizonForecast(
        horizonMinutes: h,
        mgdl: mgdl,
        lowerMgdl: (mgdl - kForecastZ90 * c.sigma).clamp(39.0, 400.0),
        upperMgdl: (mgdl + kForecastZ90 * c.sigma).clamp(39.0, 400.0),
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
