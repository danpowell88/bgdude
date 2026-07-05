/// Overnight training for the BG residual forecaster.
///
/// For each historical timestep it runs the deterministic baseline forward to each
/// horizon, compares to the actual CGM outcome, and records the residual + features.
/// Those raw samples flow through the existing [RetrainingPipeline] (annotation
/// exclusion, Huber clipping, recency/confidence weighting) before a per-horizon GBM is
/// fit. The result is scored on a held-out tail so the model registry's promotion gate
/// can accept or reject it.
library;

import '../analytics/predictor.dart';
import '../analytics/therapy_settings.dart';
import '../core/samples.dart';
import '../feedback/annotations.dart';
import '../feedback/retraining.dart';
import 'forecast_features.dart';
import 'health_features.dart';
import 'model_registry.dart';
import 'residual_gbm_model.dart';

class ForecasterTrainingResult {
  const ForecasterTrainingResult({
    required this.model,
    required this.baselineEval,
    required this.candidateEval,
    required this.trainSamples,
    required this.heldOutSamples,
  });

  final ResidualGbmModel model;

  /// Deterministic-baseline-only accuracy on the held-out tail.
  final ModelEvaluation baselineEval;

  /// Baseline + learned residual accuracy on the same held-out tail.
  final ModelEvaluation candidateEval;

  final int trainSamples;
  final int heldOutSamples;
}

class ForecasterTrainer {
  ForecasterTrainer({
    GlucosePredictor? predictor,
    this.horizons = const [30, 60, 120],
    this.strideSamples = 2,
    this.heldOutFraction = 0.2,
    RetrainingConfig? retrainingConfig,
  })  : _predictor = predictor ?? GlucosePredictor(),
        _retraining = RetrainingPipeline(
            retrainingConfig ?? const RetrainingConfig());

  final GlucosePredictor _predictor;
  final List<int> horizons;

  /// Subsample timesteps to keep the job tractable (every Nth CGM reading).
  final int strideSamples;
  final double heldOutFraction;
  final RetrainingPipeline _retraining;

  /// Returns null when there isn't enough data to train (needs a few hundred usable
  /// (timestep, horizon) pairs).
  ForecasterTrainingResult? train({
    required List<CgmSample> cgm,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required List<CarbEntry> carbs,
    required TherapySettings settings,
    required List<Annotation> annotations,
    required DateTime asOf,
    HealthFeatureSampler? health,
  }) {
    final samples = [...cgm]
      ..removeWhere((s) => s.sensorWarmup || s.mgdl <= 0)
      ..sort((a, b) => a.time.compareTo(b.time));
    if (samples.length < 60) return null;

    // Held-out split point in time (train on the older portion).
    final splitIdx = (samples.length * (1 - heldOutFraction)).floor();
    final splitTime = samples[splitIdx].time;

    final rawByHorizon = {for (final h in horizons) h: <_Raw>[]};
    final heldOut = <int, List<_Held>>{for (final h in horizons) h: []};

    for (var i = 1; i < samples.length; i += strideSamples) {
      final cur = samples[i];
      final prev = samples[i - 1];
      final gap = cur.time.difference(prev.time).inMinutes;
      final roc = gap > 0 && gap <= 15 ? (cur.mgdl - prev.mgdl) / gap : 0.0;

      final state = PredictionState(
        now: cur.time,
        currentMgdl: cur.mgdl,
        recentRocMgdlPerMin: roc,
        boluses: boluses,
        basal: basal,
        carbs: carbs,
        settings: settings,
      );
      final line = _predictor.predict(state);

      for (final h in horizons) {
        final target = cur.time.add(Duration(minutes: h));
        final actual = _nearest(samples, target);
        if (actual == null) continue;
        final baseline = _valueAt(line, target);
        final residual = actual - baseline;
        final feats = ForecastFeatures.build(
          now: cur.time,
          currentMgdl: cur.mgdl,
          recentRocMgdlPerMin: roc,
          boluses: boluses,
          basal: basal,
          carbs: carbs,
          context: SensitivityContext.neutral,
          horizonMinutes: h,
          health: health?.featuresAt(cur.time) ?? HealthFeatureSampler.zeros,
        );
        if (cur.time.isBefore(splitTime)) {
          rawByHorizon[h]!.add(_Raw(cur.time, feats, residual));
        } else {
          heldOut[h]!.add(_Held(feats, baseline, actual));
        }
      }
    }

    // Clean + weight the training set per horizon via the feedback pipeline.
    final trainingByHorizon = <int, List<TrainingSample>>{};
    var trainCount = 0;
    for (final h in horizons) {
      final cleaned = _retraining.buildTrainingSet(
        rawSamples: [
          for (final r in rawByHorizon[h]!)
            (time: r.time, features: r.features, residual: r.residual),
        ],
        annotations: annotations,
        asOf: asOf,
      );
      trainingByHorizon[h] = cleaned;
      trainCount += cleaned.length;
    }
    if (trainCount < 150) return null;

    final model = const ResidualGbmTrainer().train(trainingByHorizon);

    // Score baseline vs baseline+residual on the held-out tail.
    final baselinePairs = <({double reference, double predicted})>[];
    final candidatePairs = <({double reference, double predicted})>[];
    var heldCount = 0;
    for (final h in horizons) {
      for (final held in heldOut[h]!) {
        final corrected =
            held.baseline + model.correct(features: held.features, horizonMinutes: h).residual;
        baselinePairs.add((reference: held.actual, predicted: held.baseline));
        candidatePairs
            .add((reference: held.actual, predicted: corrected.clamp(39.0, 400.0)));
        heldCount++;
      }
    }

    const evaluator = ModelEvaluator();
    return ForecasterTrainingResult(
      model: model,
      baselineEval: evaluator.evaluate(baselinePairs),
      candidateEval: evaluator.evaluate(candidatePairs),
      trainSamples: trainCount,
      heldOutSamples: heldCount,
    );
  }

  static double? _nearest(List<CgmSample> samples, DateTime t) {
    CgmSample? best;
    var bestDelta = const Duration(minutes: 6);
    for (final s in samples) {
      final d = s.time.difference(t).abs();
      if (d <= bestDelta) {
        bestDelta = d;
        best = s;
      }
    }
    return best?.mgdl;
  }

  static double _valueAt(PredictionLine line, DateTime t) {
    var best = line.points.first;
    var bestDelta = best.time.difference(t).inSeconds.abs();
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

class _Raw {
  _Raw(this.time, this.features, this.residual);
  final DateTime time;
  final List<double> features;
  final double residual;
}

class _Held {
  _Held(this.features, this.baseline, this.actual);
  final List<double> features;
  final double baseline;
  final double actual;
}
