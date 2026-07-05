import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/units.dart';
import '../../reports/correlation_report.dart';
import '../../reports/cycle_report.dart';
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
        const _CycleCard(),
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

class _CycleCard extends ConsumerWidget {
  const _CycleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(cycleReportProvider).valueOrNull;
    if (report == null || !report.hasData) return const SizedBox.shrink();
    final unit = ref.watch(glucoseUnitProvider);
    String tir(CyclePhaseStats s) => '${(s.meanTir * 100).round()}%';
    String g(CyclePhaseStats s) =>
        '${Mgdl(s.meanGlucoseMgdl).display(unit)} ${unit.label}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Menstrual cycle', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(children: [
                    const Text('Follicular'),
                    Text('TIR ${tir(report.follicular)}'),
                    Text(g(report.follicular),
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                Expanded(
                  child: Column(children: [
                    const Text('Luteal'),
                    Text('TIR ${tir(report.luteal)}'),
                    Text(g(report.luteal),
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              report.tirDropToLuteal > 1
                  ? 'Your luteal phase ran ~${report.tirDropToLuteal.round()} TIR points '
                      'lower — consider a temporary sensitivity bump those days.'
                  : 'Little cycle-phase difference so far.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
