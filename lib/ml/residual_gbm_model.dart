/// A [ResidualModel] backed by gradient-boosted regression trees — one GBM per
/// forecast horizon, plus a per-horizon uncertainty (residual-error sigma).
///
/// This is the pure-Dart alternative to the native LiteRT residual: it needs no
/// native runtime, retrains fully on-device from the feedback pipeline's
/// [TrainingSample]s, and serialises to JSON so a nightly job can persist it and
/// the app can load it back. Each horizon is trained independently; a horizon with
/// too little data is left untrained and falls back to the widening default band.
library;

import 'dart:math' as math;

import '../feedback/retraining.dart';
import 'forecast_features.dart';
import 'forecaster.dart';
import 'gbm.dart';

/// Learned residual correction, one GBM + sigma per horizon (minutes).
class ResidualGbmModel implements ResidualModel {
  ResidualGbmModel({
    Map<int, GbmRegressor>? models,
    Map<int, double>? sigmas,
  })  : _models = models ?? {},
        _sigmas = sigmas ?? {};

  /// Trained GBM per horizon in minutes (e.g. 30/60/120).
  final Map<int, GbmRegressor> _models;

  /// 1-sigma uncertainty per horizon: held-out residual RMSE when a holdout was
  /// provided at training time, else training-set RMSE.
  final Map<int, double> _sigmas;

  /// Horizons that have a trained model.
  Iterable<int> get trainedHorizons => _models.keys;

  @override
  bool get isTrained => _models.isNotEmpty;

  @override
  ({double residual, double sigma}) correct({
    required List<double> features,
    required int horizonMinutes,
  }) {
    final model = _models[horizonMinutes];
    if (model == null || !model.isTrained) {
      // Same widening default as NoResidualModel: ~0.5 mmol at 30 min → ~2.5 at 120.
      return (residual: 0.0, sigma: 9 + horizonMinutes * 0.30);
    }
    final residual = model.predict(features);
    final sigma = _sigmas[horizonMinutes] ?? (9 + horizonMinutes * 0.30);
    return (residual: residual, sigma: sigma);
  }

  /// Bump when THIS serialization shape changes (independent of the feature
  /// layout, which [ForecastFeatures.version] tracks).
  static const int schemaVersion = 1;

  /// TASK-128: both versions are embedded IN the blob so the model and its
  /// layout version can never desync across two KvStore keys.
  Map<String, dynamic> toJson() => {
        'schema': schemaVersion,
        'featureVersion': ForecastFeatures.version,
        'models': {
          for (final e in _models.entries) '${e.key}': e.value.toJson(),
        },
        'sigmas': {
          for (final e in _sigmas.entries) '${e.key}': e.value,
        },
      };

  /// Decode a persisted model. A version mismatch (stale feature layout or an
  /// older/newer schema) yields [NoResidualModel] — fail safe, retrain fresh.
  /// Structural corruption (bad horizon keys, out-of-range tree indices/features)
  /// throws [ModelFormatException] for the store to catch.
  static ResidualModel fromJson(Map<String, dynamic> j) {
    final schema = (j['schema'] as num?)?.toInt();
    final featureVersion = (j['featureVersion'] as num?)?.toInt();
    if (schema != schemaVersion || featureVersion != ForecastFeatures.version) {
      return const NoResidualModel();
    }
    final models = <int, GbmRegressor>{};
    final rawModels = (j['models'] as Map?) ?? const {};
    for (final e in rawModels.entries) {
      final horizon = int.tryParse('${e.key}');
      if (horizon == null) {
        throw ModelFormatException('non-integer horizon key "${e.key}"');
      }
      models[horizon] = GbmRegressor.fromJson(
        e.value as Map<String, dynamic>,
        featureCount: ForecastFeatures.names.length,
      );
    }
    final sigmas = <int, double>{};
    final rawSigmas = (j['sigmas'] as Map?) ?? const {};
    for (final e in rawSigmas.entries) {
      final horizon = int.tryParse('${e.key}');
      if (horizon == null) {
        throw ModelFormatException('non-integer sigma key "${e.key}"');
      }
      sigmas[horizon] = (e.value as num).toDouble();
    }
    return ResidualGbmModel(models: models, sigmas: sigmas);
  }
}

/// Trains a [ResidualGbmModel] from per-horizon [TrainingSample]s.
class ResidualGbmTrainer {
  const ResidualGbmTrainer({
    this.minSamples = 50,
    this.maxDepth = 3,
    this.nEstimators = 50,
    this.learningRate = 0.1,
    this.minSamplesLeaf = 5,
    this.minHoldoutForSigma = 20,
  });

  /// Horizons with fewer than this many samples are skipped (left untrained).
  final int minSamples;

  final int maxDepth;
  final int nEstimators;
  final double learningRate;
  final int minSamplesLeaf;

  /// Below this many held-out rows for a horizon, sigma falls back to training RMSE.
  final int minHoldoutForSigma;

  /// Fit one GBM per horizon. [holdoutByHorizon] optionally provides held-out
  /// (features, residual-target) rows per horizon; when a horizon has enough of them,
  /// its sigma is the out-of-sample residual RMSE instead of the (optimistically
  /// biased) training-set RMSE.
  ResidualGbmModel train(
    Map<int, List<TrainingSample>> samplesByHorizon, {
    Map<int, List<({List<double> features, double target})>>? holdoutByHorizon,
  }) {
    final models = <int, GbmRegressor>{};
    final sigmas = <int, double>{};

    for (final entry in samplesByHorizon.entries) {
      final horizon = entry.key;
      final samples = entry.value;
      if (samples.length < minSamples) continue; // too little data → untrained.

      final x = samples.map((s) => s.features).toList();
      final y = samples.map((s) => s.target).toList();
      final w = samples.map((s) => s.weight).toList();

      final gbm = GbmRegressor(
        maxDepth: maxDepth,
        nEstimators: nEstimators,
        learningRate: learningRate,
        minSamplesLeaf: minSamplesLeaf,
      )..fit(x, y, sampleWeights: w);

      models[horizon] = gbm;
      // Sigma: held-out residual RMSE when available (honest out-of-sample error),
      // else training-set RMSE. Floored so we never report a zero-width band.
      final holdout = holdoutByHorizon?[horizon];
      double sigma;
      if (holdout != null && holdout.length >= minHoldoutForSigma) {
        var se = 0.0;
        for (final s in holdout) {
          final e = s.target - gbm.predict(s.features);
          se += e * e;
        }
        sigma = math.sqrt(se / holdout.length);
      } else {
        sigma = gbm.weightedRmse(x, y, sampleWeights: w);
      }
      sigmas[horizon] = math.max(sigma, 1.0);
    }

    return ResidualGbmModel(models: models, sigmas: sigmas);
  }
}
