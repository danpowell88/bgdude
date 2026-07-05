/// The Model-performance report: how well the BG forecaster has done against reality —
/// per-horizon accuracy, Clarke error-grid zones, prediction-interval calibration, and
/// the training-run history. This is the *inferred* tier (predictions vs outcomes), kept
/// separate from the clinical glucose report so model numbers never mix with real ones.
library;

import '../data/history_repository.dart';
import '../ml/accuracy_report.dart';
import '../ml/error_grid.dart';
import 'report_range.dart';

class ModelReport {
  const ModelReport({
    required this.range,
    required this.generatedAt,
    required this.accuracy,
    required this.errorGrid,
    required this.intervalCalibration,
    required this.scored,
    required this.modelRuns,
  });

  final ReportRange range;
  final DateTime generatedAt;
  final AccuracyReport accuracy;
  final ErrorGridResult errorGrid;

  /// Fraction of matured predictions whose actual fell inside the predicted interval
  /// (well-calibrated ≈ 0.90, the nominal interval).
  final double intervalCalibration;
  final int scored;
  final List<ModelRunRecord> modelRuns;

  bool get hasData => scored > 0;
}

class ModelReportBuilder {
  const ModelReportBuilder();

  ModelReport build({
    required List<StoredPrediction> predictions,
    required List<ModelRunRecord> modelRuns,
    required ReportRange range,
    required DateTime now,
  }) {
    final inRange =
        predictions.where((p) => range.contains(p.madeAt)).toList();
    final matured =
        inRange.where((p) => p.actualMgdl != null).toList();

    final pairs = [
      for (final p in matured)
        (reference: p.actualMgdl!, predicted: p.predictedMgdl),
    ];

    var inInterval = 0;
    for (final p in matured) {
      final a = p.actualMgdl!;
      if (a >= p.lowerMgdl && a <= p.upperMgdl) inInterval++;
    }

    return ModelReport(
      range: range,
      generatedAt: now,
      accuracy: const AccuracyAnalyzer().analyze(inRange),
      errorGrid: const ClarkeErrorGrid().evaluate(pairs),
      intervalCalibration: matured.isEmpty ? 0 : inInterval / matured.length,
      scored: matured.length,
      modelRuns: modelRuns,
    );
  }
}
