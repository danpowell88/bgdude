import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ml/error_grid.dart';
import '../../ml/model_registry.dart';
import '../../reports/model_report.dart';
import '../../state/providers.dart';
import 'report_range_picker.dart';

/// The Model-performance report: forecast accuracy, Clarke zones, interval calibration,
/// and training-run history. The "inferred" tier — kept clearly separate from real data.
class ModelReportScreen extends ConsumerWidget {
  const ModelReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(modelReportProvider);
    final drift = ref.watch(forecastDriftProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Model performance')),
      body: Column(
        children: [
          if (drift.sustained) const _DriftBanner(),
          const ReportRangePicker(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Could not build report: $e')),
              data: (r) => r.hasData
                  ? _Body(report: r)
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No matured predictions to score yet. Predictions are scored '
                          'once their target time passes.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// TASK-138: the visible "forecast accuracy drifting" flag — recent live error has
/// sustained-exceeded the model's trained sigma, and an out-of-band retrain has
/// been requested (see AppJobs._checkForecastDrift).
class _DriftBanner extends StatelessWidget {
  const _DriftBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.trending_down, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Forecast accuracy is drifting — recent predictions are missing by '
              'more than the model expects. A retrain has been requested.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.report});
  final ModelReport report;

  @override
  Widget build(BuildContext context) {
    final horizons = report.accuracy.byHorizon.keys.toList()..sort();
    final eg = report.errorGrid;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${report.scored} predictions scored',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Text('Accuracy by horizon',
            style: Theme.of(context).textTheme.titleMedium),
        for (final h in horizons)
          _HorizonCard(minutes: h, eval: report.accuracy.byHorizon[h]!.eval),
        const SizedBox(height: 16),
        Text('Clarke error grid',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _Row('Zone A+B (clinically acceptable)',
            '${(eg.abFraction * 100).toStringAsFixed(1)}%'),
        _Row('Dangerous (D+E)',
            '${(eg.dangerousFraction * 100).toStringAsFixed(1)}%'),
        _Row('Zone A', '${eg.zoneCounts[ClarkeZone.a] ?? 0}'),
        const SizedBox(height: 16),
        Text('Interval calibration',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _Row('Actuals inside predicted band',
            '${(report.intervalCalibration * 100).round()}% (target ~90%)'),
        const SizedBox(height: 16),
        if (report.modelRuns.isNotEmpty) ...[
          Text('Training runs', style: Theme.of(context).textTheme.titleMedium),
          for (final run in report.modelRuns.take(8))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(run.stage == 'active'
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked),
              title: Text('${run.stage} · ${run.trainedOnDays}d'),
              subtitle: Text(_fmt(run.createdAt)),
            ),
        ],
      ],
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _HorizonCard extends StatelessWidget {
  const _HorizonCard({required this.minutes, required this.eval});
  final int minutes;
  final ModelEvaluation eval;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$minutes min',
                style: Theme.of(context).textTheme.titleMedium),
            Text('RMSE ${eval.rmseMgdl.toStringAsFixed(0)}'),
            Text('MARD ${eval.mardPercent.toStringAsFixed(1)}%'),
            Text('A+B ${(eval.abFraction * 100).round()}%'),
            Text('n=${eval.sampleCount}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child:
                    Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
}
