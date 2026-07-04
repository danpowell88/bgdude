/// The feature vector for the learned BG residual model. Built identically at training
/// time (over historical timesteps) and at inference time (from the live state), so the
/// GBM sees a consistent layout. Keep the order stable; changing it invalidates any
/// persisted model (bump the [version]).
library;

import 'dart:math' as math;

import '../analytics/carb_math.dart';
import '../analytics/insulin_math.dart';
import '../analytics/predictor.dart';
import '../core/samples.dart';
import '../analytics/therapy_settings.dart';
import 'forecaster.dart';

class ForecastFeatures {
  const ForecastFeatures._();

  /// Bump when the feature layout changes so stale models are discarded.
  static const int version = 1;

  static const List<String> names = [
    'bg/100',
    'roc',
    'iob',
    'cob/10',
    'hour_sin',
    'hour_cos',
    'sensitivity',
    'horizon/60',
  ];

  static final _iob = const IobCalculator();
  static const _carb = CarbModel();

  /// Build the feature vector at [now] for a given [horizonMinutes].
  static List<double> build({
    required DateTime now,
    required double currentMgdl,
    required double recentRocMgdlPerMin,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required List<CarbEntry> carbs,
    required SensitivityContext context,
    required int horizonMinutes,
  }) {
    final iob = _iob.total(boluses, basal, now).units;
    final cob = _carb.cob(carbs, now);
    final hour = now.hour + now.minute / 60.0;
    return [
      currentMgdl / 100.0,
      recentRocMgdlPerMin,
      iob,
      cob / 10.0,
      math.sin(2 * math.pi * hour / 24),
      math.cos(2 * math.pi * hour / 24),
      context.effectiveMultiplier,
      horizonMinutes / 60.0,
    ];
  }
}

/// Forecast directly from a [PredictionState], wiring the feature builder so the
/// residual model receives the same layout it was trained on. The sensitivity feature
/// is fixed to neutral here to match training (the trainer builds features with a
/// neutral context), avoiding a train/serve skew where the GBM sees an out-of-
/// distribution value it never learned to split on.
extension ForecasterStateExt on Forecaster {
  List<HorizonForecast> forecastState(PredictionState s) => forecast(
        s,
        featureBuilder: (h) => ForecastFeatures.build(
          now: s.now,
          currentMgdl: s.currentMgdl,
          recentRocMgdlPerMin: s.recentRocMgdlPerMin,
          boluses: s.boluses,
          basal: s.basal,
          carbs: s.carbs,
          context: SensitivityContext.neutral,
          horizonMinutes: h,
        ),
      );
}
