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
import 'forecaster.dart';
import 'health_features.dart';
import 'model_registry.dart';
import 'residual_gbm_model.dart';
import 'training_census.dart';

class ForecasterTrainingResult {
  const ForecasterTrainingResult({
    required this.model,
    required this.baselineEval,
    required this.candidateEval,
    required this.trainSamples,
    required this.heldOutSamples,
    this.incumbentEval,
    this.baselineByHorizon = const {},
    this.candidateByHorizon = const {},
    this.incumbentByHorizon,
    this.census = const TrainingCensus(),
  });

  final ResidualGbmModel model;

  /// Deterministic-baseline-only accuracy on the held-out tail.
  final ModelEvaluation baselineEval;

  /// Baseline + learned residual accuracy on the same held-out tail.
  final ModelEvaluation candidateEval;

  /// Baseline + *currently live* residual model accuracy on the same held-out tail
  /// (null when no trained incumbent was passed in). This is what the candidate must
  /// beat to be promoted — not just the deterministic baseline.
  final ModelEvaluation? incumbentEval;

  final int trainSamples;
  final int heldOutSamples;

  /// TASK-130: the same evaluations split per horizon (minutes), so the gate can
  /// judge each horizon on its own evidence instead of the pooled mix.
  final Map<int, ModelEvaluation> baselineByHorizon;
  final Map<int, ModelEvaluation> candidateByHorizon;
  final Map<int, ModelEvaluation>? incumbentByHorizon;

  /// TASK-140: per-horizon training-sample counts and health-feature coverage.
  final TrainingCensus census;
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
  ///
  /// [incumbent] is the currently-live residual model; when trained, it is scored on
  /// the same held-out tail so the promotion decision can A/B candidate vs live.
  ForecasterTrainingResult? train({
    required List<CgmSample> cgm,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required List<CarbEntry> carbs,
    required TherapySettings settings,
    required List<Annotation> annotations,
    required DateTime asOf,
    HealthFeatureSampler? health,
    ResidualModel? incumbent,
  }) {
    final samples = [...cgm]
      ..removeWhere((s) => s.sensorWarmup || s.isCalibration || s.mgdl <= 0)
      ..sort((a, b) => a.time.compareTo(b.time));
    if (samples.length < 60) return null;

    // Held-out split point in time (train on the older portion).
    final splitIdx = (samples.length * (1 - heldOutFraction)).floor();
    final splitTime = samples[splitIdx].time;

    // Sorted event lists so each timestep sees only doses/carbs known at that moment.
    // The basal *schedule* stays full — it is programmed ahead and the live forecaster
    // knows it too. Boluses and carbs after `now` must not leak into the baseline,
    // otherwise training residuals are computed against a future-aware baseline the
    // live system can never have (train/serve skew).
    final sortedBoluses = [...boluses]..sort((a, b) => a.time.compareTo(b.time));
    final sortedCarbs = [...carbs]..sort((a, b) => a.time.compareTo(b.time));
    var bolusEnd = 0;
    var carbEnd = 0;

    final rawByHorizon = {for (final h in horizons) h: <_Raw>[]};
    final heldOut = <int, List<_Held>>{for (final h in horizons) h: []};

    // TASK-140: fraction of TRAINING timesteps with a real (non-zero) health
    // signal -- explains why health-dependent features aren't helping if the
    // user's wearable coverage is thin, instead of that being invisible.
    var trainingTimesteps = 0;
    var trainingTimestepsWithHealth = 0;

    for (var i = 1; i < samples.length; i += strideSamples) {
      final cur = samples[i];
      final prev = samples[i - 1];
      final gap = cur.time.difference(prev.time).inMinutes;
      final roc = gap > 0 && gap <= 15 ? (cur.mgdl - prev.mgdl) / gap : 0.0;

      while (bolusEnd < sortedBoluses.length &&
          !sortedBoluses[bolusEnd].time.isAfter(cur.time)) {
        bolusEnd++;
      }
      while (carbEnd < sortedCarbs.length &&
          !sortedCarbs[carbEnd].time.isAfter(cur.time)) {
        carbEnd++;
      }
      final knownBoluses = sortedBoluses.sublist(0, bolusEnd);
      final knownCarbs = sortedCarbs.sublist(0, carbEnd);

      final state = PredictionState(
        now: cur.time,
        currentMgdl: cur.mgdl,
        recentRocMgdlPerMin: roc,
        boluses: knownBoluses,
        basal: basal,
        carbs: knownCarbs,
        settings: settings,
      );
      final line = _predictor.predict(state);
      final healthFeats = health?.featuresAt(cur.time) ?? HealthFeatureSampler.zeros;
      final hasHealthSignal = healthFeats.any((v) => v != 0.0);
      var countedTimestep = false;

      for (final h in horizons) {
        final target = cur.time.add(Duration(minutes: h));
        final actual = nearestMgdl(samples, target);
        if (actual == null) continue;
        final baseline = valueAt(line, target);
        final residual = actual - baseline;
        final feats = ForecastFeatures.build(
          now: cur.time,
          currentMgdl: cur.mgdl,
          recentRocMgdlPerMin: roc,
          boluses: knownBoluses,
          basal: basal,
          carbs: knownCarbs,
          horizonMinutes: h,
          health: healthFeats,
        );
        if (cur.time.isBefore(splitTime)) {
          rawByHorizon[h]!.add(_Raw(cur.time, feats, residual));
          if (!countedTimestep) {
            countedTimestep = true;
            trainingTimesteps++;
            if (hasHealthSignal) trainingTimestepsWithHealth++;
          }
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

    // Held-out (features, residual-target) rows drive the model's sigma so the
    // reported uncertainty is out-of-sample, not training error.
    final holdoutByHorizon = {
      for (final h in horizons)
        h: [
          for (final held in heldOut[h]!)
            (features: held.features, target: held.actual - held.baseline),
        ],
    };
    final model = const ResidualGbmTrainer()
        .train(trainingByHorizon, holdoutByHorizon: holdoutByHorizon);

    // Score baseline vs incumbent vs baseline+candidate on the held-out tail —
    // pooled for display, and per horizon for the promotion gate (TASK-130).
    final baselinePairs = <({double reference, double predicted})>[];
    final candidatePairs = <({double reference, double predicted})>[];
    final incumbentPairs = <({double reference, double predicted})>[];
    final baselinePairsByH = <int, List<({double reference, double predicted})>>{};
    final candidatePairsByH = <int, List<({double reference, double predicted})>>{};
    final incumbentPairsByH = <int, List<({double reference, double predicted})>>{};
    final scoreIncumbent = incumbent != null && incumbent.isTrained;
    var heldCount = 0;
    for (final h in horizons) {
      final bh = baselinePairsByH[h] = [];
      final ch = candidatePairsByH[h] = [];
      final ih = incumbentPairsByH[h] = [];
      for (final held in heldOut[h]!) {
        final corrected =
            held.baseline + model.correct(features: held.features, horizonMinutes: h).residual;
        final basePair = (reference: held.actual, predicted: held.baseline);
        final candPair =
            (reference: held.actual, predicted: corrected.clamp(39.0, 400.0));
        baselinePairs.add(basePair);
        candidatePairs.add(candPair);
        bh.add(basePair);
        ch.add(candPair);
        if (scoreIncumbent) {
          final liveCorrected = held.baseline +
              incumbent.correct(features: held.features, horizonMinutes: h).residual;
          final incPair =
              (reference: held.actual, predicted: liveCorrected.clamp(39.0, 400.0));
          incumbentPairs.add(incPair);
          ih.add(incPair);
        }
        heldCount++;
      }
    }

    const evaluator = ModelEvaluator();
    return ForecasterTrainingResult(
      model: model,
      baselineEval: evaluator.evaluate(baselinePairs),
      candidateEval: evaluator.evaluate(candidatePairs),
      incumbentEval: scoreIncumbent ? evaluator.evaluate(incumbentPairs) : null,
      baselineByHorizon: {
        for (final h in horizons) h: evaluator.evaluate(baselinePairsByH[h]!),
      },
      candidateByHorizon: {
        for (final h in horizons) h: evaluator.evaluate(candidatePairsByH[h]!),
      },
      incumbentByHorizon: scoreIncumbent
          ? {for (final h in horizons) h: evaluator.evaluate(incumbentPairsByH[h]!)}
          : null,
      trainSamples: trainCount,
      heldOutSamples: heldCount,
      census: TrainingCensus(
        perHorizonSamples: {
          for (final h in horizons) h: trainingByHorizon[h]!.length,
        },
        healthFeatureCoverage: trainingTimesteps == 0
            ? null
            : trainingTimestepsWithHealth / trainingTimesteps,
      ),
    );
  }

  /// Lower bound (first index whose time is not before [t]) over a
  /// time-sorted list — the TASK-134 replacement for the full linear scans
  /// that made training cost quadratic in history length.
  static int _lowerBound<T>(
      List<T> xs, DateTime t, DateTime Function(T) timeOf) {
    var lo = 0, hi = xs.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (timeOf(xs[mid]).isBefore(t)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Nearest confirmed reading to [t] within ±6 min, by binary search over the
  /// time-sorted [samples]. Tie (equidistant neighbours) goes to the LATER
  /// sample — identical to the old scan's `<=` update rule. Public for the
  /// linear-vs-binary equivalence test.
  static double? nearestMgdl(List<CgmSample> samples, DateTime t) {
    if (samples.isEmpty) return null;
    const cap = Duration(minutes: 6);
    final i = _lowerBound(samples, t, (s) => s.time);
    CgmSample? best;
    var bestDelta = cap;
    if (i > 0) {
      final s = samples[i - 1];
      final d = t.difference(s.time).abs();
      if (d <= bestDelta) {
        bestDelta = d;
        best = s;
      }
    }
    if (i < samples.length) {
      final s = samples[i];
      final d = s.time.difference(t).abs();
      if (d <= bestDelta) {
        // <= so the later of two equidistant samples wins, like the old scan.
        best = s;
      }
    }
    return best?.mgdl;
  }

  /// Baseline value at [t] from the prediction line's fixed-cadence points, by
  /// binary search. Tie goes to the EARLIER point — identical to the old scan's
  /// strict `<` update rule. Public for the equivalence test.
  static double valueAt(PredictionLine line, DateTime t) {
    final pts = line.points;
    final i = _lowerBound(pts, t, (p) => p.time);
    var best = pts[i > 0 ? i - 1 : 0];
    if (i < pts.length) {
      final dAfter = pts[i].time.difference(t).abs();
      final dBest = best.time.difference(t).abs();
      if (dAfter < dBest) best = pts[i];
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
