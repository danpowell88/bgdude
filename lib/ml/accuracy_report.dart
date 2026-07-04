/// Scores logged predictions against the actual outcomes the repository back-filled,
/// per horizon, using the same error-grid + hypo metrics as the promotion gate. This is
/// how the app shows "how well are the forecasts doing on MY data" — model diagnostics,
/// not a clinical report.
library;

import '../data/history_repository.dart';
import 'model_registry.dart';

class AccuracyReport {
  const AccuracyReport({
    required this.byHorizon,
    required this.overall,
    required this.scored,
    required this.pending,
  });

  final Map<int, ModelEvaluation> byHorizon;
  final ModelEvaluation? overall;
  final int scored;
  final int pending;

  bool get hasData => scored > 0;
}

class AccuracyAnalyzer {
  const AccuracyAnalyzer();

  AccuracyReport analyze(List<StoredPrediction> predictions) {
    final scored = [for (final p in predictions) if (p.actualMgdl != null) p];
    final pending = predictions.length - scored.length;

    const evaluator = ModelEvaluator();
    final byHorizon = <int, ModelEvaluation>{};
    final horizons = {for (final p in scored) p.horizonMinutes};
    for (final h in horizons) {
      final pairs = [
        for (final p in scored)
          if (p.horizonMinutes == h)
            (reference: p.actualMgdl!, predicted: p.predictedMgdl),
      ];
      if (pairs.isNotEmpty) byHorizon[h] = evaluator.evaluate(pairs);
    }

    final allPairs = [
      for (final p in scored)
        (reference: p.actualMgdl!, predicted: p.predictedMgdl),
    ];
    return AccuracyReport(
      byHorizon: Map.fromEntries(
          byHorizon.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
      overall: allPairs.isEmpty ? null : evaluator.evaluate(allPairs),
      scored: scored.length,
      pending: pending,
    );
  }
}
