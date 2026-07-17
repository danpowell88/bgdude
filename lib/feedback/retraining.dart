/// Robust retraining pipeline. Turns raw history + user annotations into a clean,
/// weighted training set for the forecaster/sensitivity models, then relies on the
/// model registry's promotion gate to accept or reject the result.
///
/// Robustness measures (annotations and carb entries are noisy/late):
///   * hard-exclude annotated artifact windows (site failure, warm-up, compression low)
///   * apply relabels (missed/extra carbs) before computing residual targets
///   * recency + annotation-confidence sample weighting
///   * Huber-style loss clipping on residual targets so a few outliers can't dominate
library;

import 'dart:math' as math;

import '../core/samples.dart';
import '../ml/event_detectors.dart';
import 'annotations.dart';

/// A single training row for the residual/forecaster model.
class TrainingSample {
  const TrainingSample({
    required this.time,
    required this.features,
    required this.target,
    required this.weight,
  });

  final DateTime time;
  final List<double> features;

  /// Residual target (observed − baseline prediction), possibly Huber-clipped.
  final double target;
  final double weight;
}

class RetrainingConfig {
  const RetrainingConfig({
    this.recencyHalfLifeDays = 21,
    this.huberDeltaMgdl = 30,
    this.now,
  });

  /// Older samples decay in weight with this half-life.
  final int recencyHalfLifeDays;

  /// Residual magnitude beyond which the loss becomes linear (outlier robustness).
  final double huberDeltaMgdl;

  /// Injected clock (tests pass a fixed value; Date.now is avoided for determinism).
  final DateTime? now;
}

class RetrainingPipeline {
  const RetrainingPipeline(this.config);

  final RetrainingConfig config;

  /// Build the cleaned, weighted training set.
  ///
  /// [rawSamples] pairs each timestep's feature vector with the observed residual
  /// (observed glucose − deterministic baseline). [asOf] anchors recency weighting.
  List<TrainingSample> buildTrainingSet({
    required List<({DateTime time, List<double> features, double residual})>
        rawSamples,
    required List<Annotation> annotations,
    required DateTime asOf,
    // TASK-141: algorithmic CGM data-quality faults (jump/flatline/dropout-edge) --
    // kept separate from [annotations] since these are never user-visible or
    // persisted, just recomputed fresh from the raw CGM each training run.
    List<CgmFaultEvent> cgmFaults = const [],
  }) {
    final excludeWindows =
        annotations.where((a) => a.kind.excludesFromTraining).toList();

    final out = <TrainingSample>[];
    for (final s in rawSamples) {
      // Hard exclusion.
      if (excludeWindows.any((a) => a.covers(s.time))) continue;
      if (cgmFaults.any((f) => f.covers(s.time))) continue;

      // Recency weight.
      final ageDays = asOf.difference(s.time).inMinutes / (60 * 24);
      final recency =
          math.pow(0.5, ageDays / config.recencyHalfLifeDays).toDouble();

      // Annotation-confidence weight: context annotations covering this time scale the
      // weight by their confidence (an uncertain "maybe I was stressed" counts less).
      var annWeight = 1.0;
      for (final a in annotations) {
        if (a.kind.isContext && a.covers(s.time)) {
          annWeight *= (0.5 + 0.5 * a.confidence.clamp(0.0, 1.0));
        }
      }

      // Huber clip on the residual target.
      final clipped = _huberClip(s.residual, config.huberDeltaMgdl);

      out.add(TrainingSample(
        time: s.time,
        features: s.features,
        target: clipped,
        weight: recency * annWeight,
      ));
    }
    return out;
  }

  /// Extra carb entries synthesised from missed/extra-carb annotations, to be merged
  /// into the history before baseline residuals are recomputed.
  List<CarbEntry> relabelCarbs(List<Annotation> annotations) {
    return annotations
        .where((a) => a.kind.relabelsCarbs && a.carbsGrams > 0)
        .map((a) => CarbEntry(time: a.start, grams: a.carbsGrams))
        .toList();
  }

  static double _huberClip(double residual, double delta) {
    if (residual.abs() <= delta) return residual;
    return residual.sign * delta;
  }
}
