/// Scores logged predictions against the actual outcomes the repository back-filled,
/// per horizon, using the same error-grid + hypo metrics as the promotion gate. This is
/// how the app shows "how well are the forecasts doing on MY data" — model diagnostics,
/// not a clinical report.
library;

import '../analytics/band_coverage.dart';
import '../data/history_repository.dart';
import 'model_registry.dart';

/// A [ModelEvaluation] plus the two honesty checks on the predicted band itself
/// (TASK-17): how often the actual reading landed inside `[lower, upper]`
/// (coverage) and whether the band is centred (bias). Kept separate from
/// [ModelEvaluation] itself so the model-promotion gate (which scores pairs with
/// no band data) is untouched.
class BandEvaluation {
  const BandEvaluation({
    required this.eval,
    required this.coverageFraction,
    required this.biasMgdl,
  });

  final ModelEvaluation eval;

  /// Fraction of scored predictions whose actual reading fell in `[lower, upper]`.
  /// A well-calibrated band should catch roughly its nominal confidence level.
  final double coverageFraction;

  /// Mean signed error, predicted − actual, mg/dL. Positive = the model runs
  /// high; negative = runs low; 0 is perfectly centred.
  final double biasMgdl;
}

class AccuracyReport {
  const AccuracyReport({
    required this.byHorizon,
    required this.overall,
    required this.scored,
    required this.pending,
  });

  final Map<int, BandEvaluation> byHorizon;
  final BandEvaluation? overall;
  final int scored;
  final int pending;

  bool get hasData => scored > 0;
}

class AccuracyAnalyzer {
  const AccuracyAnalyzer();

  BandEvaluation _evaluate(List<StoredPrediction> scoredForGroup) {
    final pairs = [
      for (final p in scoredForGroup)
        (reference: p.actualMgdl!.value, predicted: p.predictedMgdl.value),
    ];
    final coverage = computeBandCoverage([
      for (final p in scoredForGroup)
        (
          actual: p.actualMgdl!.value,
          lower: p.lowerMgdl.value,
          upper: p.upperMgdl.value
        ),
    ]);
    final bias = pairs.isEmpty
        ? 0.0
        : pairs.map((p) => p.predicted - p.reference).reduce((a, b) => a + b) /
            pairs.length;
    return BandEvaluation(
      eval: const ModelEvaluator().evaluate(pairs),
      coverageFraction: coverage.fraction,
      biasMgdl: bias,
    );
  }

  AccuracyReport analyze(List<StoredPrediction> predictions) {
    final scored = [for (final p in predictions) if (p.actualMgdl != null) p];
    final pending = predictions.length - scored.length;

    final byHorizon = <int, BandEvaluation>{};
    final horizons = {for (final p in scored) p.horizonMinutes};
    for (final h in horizons) {
      final group = [for (final p in scored) if (p.horizonMinutes == h) p];
      if (group.isNotEmpty) byHorizon[h] = _evaluate(group);
    }

    return AccuracyReport(
      byHorizon: Map.fromEntries(
          byHorizon.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
      overall: scored.isEmpty ? null : _evaluate(scored),
      scored: scored.length,
      pending: pending,
    );
  }
}
