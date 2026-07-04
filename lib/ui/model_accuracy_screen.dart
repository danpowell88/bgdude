import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ml/accuracy_report.dart';
import '../ml/model_registry.dart';
import '../state/providers.dart';

/// Reconciles matured predictions and scores them per horizon, so you can see how the
/// forecaster is actually doing on your data (Clarke A+B, RMSE, hypo sensitivity).
final accuracyReportProvider = FutureProvider<AccuracyReport>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  final now = DateTime.now();
  await repo.reconcilePredictions(now);
  final preds = await repo.predictions(now.subtract(const Duration(days: 14)), now);
  return const AccuracyAnalyzer().analyze(preds);
});

/// Reconciled prediction points for the Clarke error grid (reference = actual).
final errorGridPointsProvider =
    FutureProvider<List<({double referenceMgdl, double predictedMgdl})>>(
        (ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  final now = DateTime.now();
  await repo.reconcilePredictions(now);
  final preds = await repo.predictions(now.subtract(const Duration(days: 14)), now);
  return [
    for (final p in preds)
      if (p.actualMgdl != null)
        (referenceMgdl: p.actualMgdl!, predictedMgdl: p.predictedMgdl),
  ];
});

class ModelAccuracyScreen extends ConsumerWidget {
  const ModelAccuracyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(accuracyReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Forecast accuracy')),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (r) => !r.hasData
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No scored predictions yet. Predictions are checked against what '
                    'actually happened once their horizon has passed — come back after '
                    'a few hours of data.${r.pending > 0 ? '\n\n${r.pending} predictions are waiting to mature.' : ''}',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('${r.scored} predictions scored'
                      '${r.pending > 0 ? ' · ${r.pending} maturing' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  for (final entry in r.byHorizon.entries)
                    _HorizonAccuracyCard(
                        horizon: entry.key, eval: entry.value),
                  const SizedBox(height: 12),
                  Text(
                    'Clarke A+B is the clinically-safe fraction; a retrained model must '
                    'clear 95% here (and beat the physics baseline) before it goes live.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HorizonAccuracyCard extends StatelessWidget {
  const _HorizonAccuracyCard({required this.horizon, required this.eval});
  final int horizon;
  final ModelEvaluation eval;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('+$horizon min',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _stat(context, 'RMSE', '${eval.rmseMgdl.toStringAsFixed(1)} mg/dL'),
            _stat(context, 'Clarke A+B',
                '${(eval.abFraction * 100).toStringAsFixed(1)}%'),
            _stat(context, 'Hypo sensitivity',
                '${(eval.hypoSensitivity * 100).toStringAsFixed(0)}%'),
            _stat(context, 'Samples', '${eval.sampleCount}'),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 150, child: Text(k)),
            Text(v,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
