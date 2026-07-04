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

  /// Weighted RMSE of training residuals per horizon → 1-sigma uncertainty.
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

  Map<String, dynamic> toJson() => {
        'models': {
          for (final e in _models.entries) '${e.key}': e.value.toJson(),
        },
        'sigmas': {
          for (final e in _sigmas.entries) '${e.key}': e.value,
        },
      };

  static ResidualGbmModel fromJson(Map<String, dynamic> j) {
    final models = <int, GbmRegressor>{};
    final rawModels = (j['models'] as Map?) ?? const {};
    for (final e in rawModels.entries) {
      models[int.parse(e.key as String)] =
          GbmRegressor.fromJson(e.value as Map<String, dynamic>);
    }
    final sigmas = <int, double>{};
    final rawSigmas = (j['sigmas'] as Map?) ?? const {};
    for (final e in rawSigmas.entries) {
      sigmas[int.parse(e.key as String)] = (e.value as num).toDouble();
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
  });

  /// Horizons with fewer than this many samples are skipped (left untrained).
  final int minSamples;

  final int maxDepth;
  final int nEstimators;
  final double learningRate;
  final int minSamplesLeaf;

  ResidualGbmModel train(Map<int, List<TrainingSample>> samplesByHorizon) {
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
      // Sigma = weighted RMSE of residuals on the training set, floored so we never
      // report an overconfident zero-width band.
      final rmse = gbm.weightedRmse(x, y, sampleWeights: w);
      sigmas[horizon] = math.max(rmse, 1.0);
    }

    return ResidualGbmModel(models: models, sigmas: sigmas);
  }
}
