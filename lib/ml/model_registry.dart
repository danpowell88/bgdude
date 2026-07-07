/// Model registry + promotion safety gate.
///
/// Keeps a *frozen* base model and a *candidate* fine-tuned model. A candidate is only
/// promoted to "active" if it passes an error-grid + hypo-sensitivity gate on a held-out
/// window — this prevents a bad retraining run (driven by noisy/mislabelled feedback)
/// from degrading the live forecast. The registry is storage-agnostic; persistence is
/// handled by the data layer.
library;

import 'dart:math' as math;

import 'error_grid.dart';

enum ModelStage { base, candidate, active, retired }

class ModelVersion {
  const ModelVersion({
    required this.id,
    required this.stage,
    required this.createdAt,
    required this.trainedOnDays,
    this.parentId,
    this.metrics,
  });

  final String id;
  final ModelStage stage;
  final DateTime createdAt;
  final int trainedOnDays;
  final String? parentId;
  final ModelEvaluation? metrics;

  ModelVersion copyWith({ModelStage? stage, ModelEvaluation? metrics}) =>
      ModelVersion(
        id: id,
        stage: stage ?? this.stage,
        createdAt: createdAt,
        trainedOnDays: trainedOnDays,
        parentId: parentId,
        metrics: metrics ?? this.metrics,
      );
}

class ModelEvaluation {
  const ModelEvaluation({
    required this.rmseMgdl,
    required this.abFraction,
    required this.dangerousFraction,
    required this.hypoSensitivity,
    required this.hypoFalseAlarmRate,
    required this.sampleCount,
  });

  final double rmseMgdl;
  final double abFraction;
  final double dangerousFraction;

  /// Null when the evaluation window has no true lows (nothing to detect); the
  /// promotion gate skips the hypo-sensitivity criterion in that case.
  final double? hypoSensitivity;

  /// Null when the evaluation window has no true not-lows.
  final double? hypoFalseAlarmRate;
  final int sampleCount;
}

/// Thresholds a candidate must satisfy to be promoted.
class PromotionGate {
  const PromotionGate({
    this.minAbFraction = 0.95,
    this.maxDangerousFraction = 0.02,
    this.minHypoSensitivity = 0.80,
    this.maxRmseRegressionMgdl = 3.0,
    this.minSampleCount = 288, // ~1 day of 5-min points held out
  });

  final double minAbFraction;
  final double maxDangerousFraction;
  final double minHypoSensitivity;

  /// A candidate may not be worse than the active model by more than this RMSE.
  final double maxRmseRegressionMgdl;
  final int minSampleCount;

  ({bool pass, List<String> reasons}) evaluate(
    ModelEvaluation candidate, {
    ModelEvaluation? incumbent,
  }) {
    final reasons = <String>[];
    if (candidate.sampleCount < minSampleCount) {
      reasons.add('insufficient held-out samples (${candidate.sampleCount})');
    }
    if (candidate.abFraction < minAbFraction) {
      reasons.add(
          'Clarke A+B ${(candidate.abFraction * 100).toStringAsFixed(1)}% < ${(minAbFraction * 100).toStringAsFixed(0)}%');
    }
    if (candidate.dangerousFraction > maxDangerousFraction) {
      reasons.add(
          'dangerous zone ${(candidate.dangerousFraction * 100).toStringAsFixed(1)}% > ${(maxDangerousFraction * 100).toStringAsFixed(0)}%');
    }
    // Skipped when the held-out window has no true lows: there was nothing to
    // detect, which must not read as "missed every low".
    final hypoSens = candidate.hypoSensitivity;
    if (hypoSens != null && hypoSens < minHypoSensitivity) {
      reasons.add(
          'hypo sensitivity ${(hypoSens * 100).toStringAsFixed(0)}% < ${(minHypoSensitivity * 100).toStringAsFixed(0)}%');
    }
    if (incumbent != null &&
        candidate.rmseMgdl > incumbent.rmseMgdl + maxRmseRegressionMgdl) {
      reasons.add(
          'RMSE regressed ${(candidate.rmseMgdl - incumbent.rmseMgdl).toStringAsFixed(1)} mg/dL vs active');
    }
    return (pass: reasons.isEmpty, reasons: reasons);
  }

  /// TASK-130: judge each horizon on its own evidence — pooled stats let a
  /// candidate that improves 30-min but regresses 120-min ship anyway.
  ///
  /// Promotion is ALL-PASS across the trained horizons: one model blob is
  /// persisted (there is no per-horizon promotion), so a candidate that fails the
  /// gate or does not strictly improve RMSE (vs that horizon's incumbent, or the
  /// baseline when none) at ANY trained horizon does not ship. Horizons the
  /// candidate left untrained keep baseline behaviour and are not gated.
  ({bool promoted, List<String> reasons}) decideAcrossHorizons({
    required Map<int, ModelEvaluation> candidateByHorizon,
    required Map<int, ModelEvaluation> baselineByHorizon,
    Map<int, ModelEvaluation>? incumbentByHorizon,
    required Iterable<int> trainedHorizons,
  }) {
    final reasons = <String>[];
    final horizons = [
      for (final h in candidateByHorizon.keys)
        if (trainedHorizons.contains(h)) h,
    ]..sort();
    if (horizons.isEmpty) {
      return (promoted: false, reasons: ['no trained horizons to gate']);
    }
    var pass = true;
    var improvesBaseline = true;
    var improvesIncumbent = true;
    for (final h in horizons) {
      final cand = candidateByHorizon[h]!;
      final base = baselineByHorizon[h];
      final inc = incumbentByHorizon?[h];
      final g = evaluate(cand, incumbent: inc ?? base);
      if (!g.pass) {
        pass = false;
        reasons.addAll(g.reasons.map((r) => '${h}m: $r'));
      }
      if (base != null && cand.rmseMgdl >= base.rmseMgdl) {
        improvesBaseline = false;
      }
      if (inc != null && cand.rmseMgdl >= inc.rmseMgdl) {
        improvesIncumbent = false;
      }
    }
    // Aggregate strings kept stable for callers/tests that match on them.
    if (!improvesBaseline) reasons.add('no RMSE improvement over baseline');
    if (!improvesIncumbent) {
      reasons.add('no RMSE improvement over the active model');
    }
    return (
      promoted: pass && improvesBaseline && improvesIncumbent,
      reasons: reasons,
    );
  }
}

/// Builds a ModelEvaluation from raw prediction/reference pairs.
class ModelEvaluator {
  const ModelEvaluator();

  ModelEvaluation evaluate(
    List<({double reference, double predicted})> pairs,
  ) {
    final grid = const ClarkeErrorGrid().evaluate(pairs);
    final hypo = HypoDetectionStats.fromPairs(pairs);
    var se = 0.0;
    for (final p in pairs) {
      final d = p.predicted - p.reference;
      se += d * d;
    }
    final rmse = pairs.isEmpty ? double.infinity : math.sqrt(se / pairs.length);
    return ModelEvaluation(
      rmseMgdl: rmse,
      abFraction: grid.abFraction,
      dangerousFraction: grid.dangerousFraction,
      hypoSensitivity: hypo.sensitivity,
      hypoFalseAlarmRate: hypo.falseAlarmRate,
      sampleCount: pairs.length,
    );
  }
}

class ModelRegistry {
  ModelRegistry({List<ModelVersion>? versions})
      : _versions = versions ?? <ModelVersion>[];

  final List<ModelVersion> _versions;
  final PromotionGate gate = const PromotionGate();

  List<ModelVersion> get versions => List.unmodifiable(_versions);

  ModelVersion? get active =>
      _versions.where((v) => v.stage == ModelStage.active).firstOrNull;

  void register(ModelVersion v) => _versions.add(v);

  /// Attempt to promote [candidate]; returns the gate decision. On pass, the previous
  /// active model is retired.
  ({bool promoted, List<String> reasons}) tryPromote(ModelVersion candidate) {
    final decision =
        gate.evaluate(candidate.metrics!, incumbent: active?.metrics);
    if (!decision.pass) return (promoted: false, reasons: decision.reasons);

    final idx = _versions.indexWhere((v) => v.id == candidate.id);
    for (var i = 0; i < _versions.length; i++) {
      if (_versions[i].stage == ModelStage.active) {
        _versions[i] = _versions[i].copyWith(stage: ModelStage.retired);
      }
    }
    if (idx >= 0) {
      _versions[idx] = candidate.copyWith(stage: ModelStage.active);
    } else {
      register(candidate.copyWith(stage: ModelStage.active));
    }
    return (promoted: true, reasons: const []);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
