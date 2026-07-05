import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reports/correlation_report.dart';
import '../../state/providers.dart';
import 'report_range_picker.dart';

/// The Correlation report: daily glucose outcomes vs confirmed lifestyle inputs.
class CorrelationReportScreen extends ConsumerWidget {
  const CorrelationReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(correlationReportProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Correlations')),
      body: Column(
        children: [
          const ReportRangePicker(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not analyse: $e')),
              data: (r) => r.hasData
                  ? _Body(report: r)
                  : _Empty(days: r.daysAnalyzed),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.report});
  final CorrelationReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${report.daysAnalyzed} days analysed',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        for (final f in report.findings) _FindingCard(finding: f),
        const SizedBox(height: 12),
        Text(
          'Correlation is not causation — these are prompts to explore, not conclusions. '
          'Only associations backed by enough days are shown.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});
  final CorrelationFinding finding;

  @override
  Widget build(BuildContext context) {
    final strong = finding.strength >= 0.5;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${finding.predictorLabel} ↔ ${finding.outcomeLabel}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      strong ? cs.primaryContainer : cs.surfaceContainerHighest,
                  label: Text('r ${finding.r.toStringAsFixed(2)}'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(finding.message),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.days});
  final int days;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          days < 7
              ? 'Need at least a week of overlapping glucose + wearable data to find '
                  'reliable associations. Keep syncing Health Connect.'
              : 'No associations strong enough to report yet over $days days.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
