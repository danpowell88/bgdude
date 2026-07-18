import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/forecast_decomposition.dart';
import '../analytics/predictor.dart';
import '../ml/event_detectors.dart';
import '../ml/forecast_features.dart';
import '../state/providers.dart';
import 'app_routes.dart';
import 'log_viewer_screen.dart';
import 'model_accuracy_screen.dart';
import 'widgets/forecast_explain_card.dart';
import 'widgets/error_grid_chart.dart';

/// Advanced mode: the model internals the simple UI hides — the effective sensitivity
/// context, the learned time-of-day profile, forecaster training state, and a Clarke
/// error grid of recent predictions. Everything here is read-only diagnostics.
class AdvancedScreen extends ConsumerWidget {
  const AdvancedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advanced = ref.watch(advancedModeProvider);
    final ctx = ref.watch(effectiveSensitivityProvider);
    final profile = ref.watch(timeOfDayProfileProvider);
    final residualTrained = ref.watch(forecasterModelProvider).isTrained;
    final lastOutcome =
        ref.watch(forecasterModelProvider.notifier).lastOutcome;
    final census = ref.watch(sensitivityCensusProvider);
    final dataQualityFault = ref.watch(cgmDataQualityProvider);
    final unit = ref.watch(glucoseUnitProvider);
    final points = ref.watch(errorGridPointsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Advanced mode'),
            subtitle: const Text(
                'Show prediction decomposition and model internals throughout'),
            value: advanced,
            onChanged: (v) =>
                ref.read(advancedModeProvider.notifier).state = v,
          ),
          const Divider(),

          // Issue #73: the toggle above promises "prediction decomposition"; this is
          // it. Gated on `advanced` so the promise and the payload agree — and it is
          // presentation only, so nothing here is persisted.
          if (advanced) ...[
            Builder(builder: (context) {
              final state = ref.watch(livePredictionStateProvider);
              if (state == null) return const SizedBox.shrink();
              return ForecastExplainCard(
                decompositions:
                    const ForecastDecomposer().decompose(GlucosePredictor(), state),
                forecasts: ref.watch(calibratedForecastsProvider),
                unit: ref.watch(glucoseUnitProvider),
              );
            }),
            const SizedBox(height: 8),
          ],

          Text('CGM data quality', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                dataQualityFault == null
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
                color: dataQualityFault == null ? null : Colors.orange,
              ),
              title: Text(dataQualityFault == null
                  ? 'Current reading looks clean'
                  : dataQualityFault.label),
              subtitle: const Text(
                  'Jump/flatline/dropout-edge readings are excluded from '
                  'forecaster training automatically.'),
            ),
          ),

          const SizedBox(height: 16),
          Text('Effective sensitivity',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(context, 'Multiplier',
                      '×${ctx.effectiveMultiplier.toStringAsFixed(2)}'),
                  _kv(context, 'Raw / confidence',
                      '×${ctx.resistanceMultiplier.toStringAsFixed(2)} @ ${(ctx.confidence * 100).round()}%'),
                  _kv(context, 'Drivers',
                      ctx.reasons.isEmpty ? 'none' : ctx.reasons.join(', ')),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text('Time-of-day profile',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: profile == null || profile.isNeutral
                  ? const Text('Not learned yet — needs ~2 weeks of data.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final b in profile.buckets)
                          _kv(
                            context,
                            '${(b.startMinute ~/ 60).toString().padLeft(2, '0')}:00',
                            '×${b.multiplier.toStringAsFixed(2)} '
                                '(${(b.confidence * 100).round()}%) · '
                                '${census.perBucketMinutes[b.startMinute] ?? 0} min observed',
                          ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),
          Text('Training data', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(context, 'Sensitivity days',
                      '${census.usableDays} usable / ${census.totalDays} considered'),
                  if (lastOutcome.census.perHorizonSamples.isNotEmpty)
                    _kv(
                        context,
                        'Forecaster samples',
                        lastOutcome.census.perHorizonSamples.entries
                            .map((e) => '${e.key}m: ${e.value}')
                            .join(', ')),
                  if (lastOutcome.census.healthFeatureCoverage != null)
                    _kv(
                        context,
                        'Health data coverage',
                        '${(lastOutcome.census.healthFeatureCoverage! * 100).round()}% '
                            'of training rows'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text('Forecaster', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(context, 'Learned residual',
                      residualTrained ? 'active' : 'deterministic only'),
                  if (lastOutcome.trained) ...[
                    _kv(context, 'Last train',
                        lastOutcome.promoted ? 'promoted' : 'kept previous'),
                    _kv(context, 'RMSE cand/base',
                        '${lastOutcome.candidateRmse?.toStringAsFixed(1) ?? '—'} / ${lastOutcome.baselineRmse?.toStringAsFixed(1) ?? '—'}'),
                    if (lastOutcome.incumbentRmse != null)
                      _kv(context, 'RMSE active',
                          lastOutcome.incumbentRmse!.toStringAsFixed(1)),
                    if (lastOutcome.reasons.isNotEmpty)
                      _kv(context, 'Notes', lastOutcome.reasons.join('; ')),
                    for (final entry in lastOutcome.importanceByHorizon.entries)
                      _kv(context, 'Top features (${entry.key}m)',
                          _topFeatures(entry.value)),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Text('Clarke error grid',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const ModelAccuracyScreen()),
                ),
                child: const Text('Stats'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          points.when(
            loading: () => const SizedBox(
                height: 200, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('$e'),
            data: (pts) => pts.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No scored predictions yet.'),
                    ),
                  )
                : ErrorGridChart(points: pts, unit: unit),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('System health'),
              subtitle: const Text(
                  'Last-success time and failure count per background subsystem '
                  '(health sync, training, reconciliation, Garmin, weather, model '
                  'download).'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => AppRoutes.push(context, AppRoute.systemHealth),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Diagnostics log'),
              subtitle: const Text(
                  'Recent on-device errors and events (read-only). Nothing is sent '
                  'anywhere — for diagnosing issues in the field.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const LogViewerScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(k)),
            Expanded(
                child: Text(v,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  /// TASK-142: top 3 features by permutation importance, human-readable via
  /// [ForecastFeatures.names] -- which features actually earn their place in
  /// this horizon's model, not just an opaque index list.
  String _topFeatures(Map<int, double> importance) {
    if (importance.isEmpty) return 'n/a';
    final sorted = importance.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(3)
        .map((e) {
          final name = e.key < ForecastFeatures.names.length
              ? ForecastFeatures.names[e.key]
              : 'f${e.key}';
          return '$name (+${e.value.toStringAsFixed(1)})';
        })
        .join(', ');
  }
}
