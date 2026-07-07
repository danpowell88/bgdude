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
import 'forecaster.dart';
import 'health_features.dart';

class ForecastFeatures {
  const ForecastFeatures._();

  /// Bump when the feature layout changes so stale models are discarded.
  /// v2: appended the [HealthFeatureSampler] activity features (Google Fit / Health
  /// Connect) so the residual model can learn exercise/activity effects on BG.
  /// v3: added the heart-rate-relative feature (exercise/stress signal).
  /// v4: dropped the sensitivity-multiplier slot — both trainer and server always
  /// passed the neutral context, so it was a constant-1.0 column the GBM could
  /// never split on.
  static const int version = 4;

  static const List<String> names = [
    'bg/100',
    'roc',
    'iob',
    'cob/10',
    'hour_sin',
    'hour_cos',
    'horizon/60',
    ...HealthFeatureSampler.names,
  ];

  static const _iob = IobCalculator();
  static const _carb = CarbModel();

  /// Build the feature vector at [now] for a given [horizonMinutes]. [health] is the
  /// activity-feature contribution (defaults to zeros when no wearable data covers
  /// [now]); it must have length [HealthFeatureSampler.featureCount].
  static List<double> build({
    required DateTime now,
    required double currentMgdl,
    required double recentRocMgdlPerMin,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required List<CarbEntry> carbs,
    required int horizonMinutes,
    List<double> health = HealthFeatureSampler.zeros,
  }) {
    // TASK-131 contract: [now] must be LOCAL wall-clock time. A UTC timestamp
    // shifts hour_sin/hour_cos by the UTC offset and corrupts training data
    // silently; ingest converts once (CgmSample), this assert catches leaks.
    assert(!now.isUtc, 'time-of-day features need local wall-clock time, got UTC');
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
      horizonMinutes / 60.0,
      ...health,
    ];
  }
}

/// Forecast directly from a [PredictionState], wiring the feature builder so the
/// residual model receives the same layout it was trained on. The activity features
/// come from the live [PredictionState.healthFeatures], computed by the same
/// [HealthFeatureSampler] logic the trainer uses.
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
          horizonMinutes: h,
          health: s.healthFeatures,
        ),
      );
}
