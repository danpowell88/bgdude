import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reports/therapy_report.dart';
import '../../state/providers.dart';
import '../basal_recommendations_screen.dart';
import '../widgets/chart_axis.dart';
import 'report_range_picker.dart';

/// The Therapy report: learned sensitivity drift (Autotune trend), the time-of-day
/// profile, and a link to the basal suggestions. Advisory only.
class TherapyReportScreen extends ConsumerWidget {
  const TherapyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(therapyReportProvider);
    final profile = ref.watch(timeOfDayProfileProvider);
    final basal = ref.watch(basalRecommendationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Therapy report')),
      body: Column(
        children: [
          const ReportRangePicker(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not build report: $e')),
              data: (r) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!r.hasData)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Not enough carb-free (fasting) data in this range to learn '
                        'sensitivity yet.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else ...[
                    _Headline(report: r),
                    const SizedBox(height: 16),
                    Text('Daily sensitivity (Autotune)',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(height: 180, child: _TrendChart(report: r)),
                    Text('>1.0 = needed more insulin than settings (resistant); '
                        '<1.0 = more sensitive.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 20),
                  if (profile != null && !profile.isNeutral) ...[
                    Text('Time-of-day sensitivity',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final b in profile.buckets)
                      if (b.confidence > 0.2)
                        _BucketRow(
                          startMinute: b.startMinute,
                          multiplier: b.multiplier,
                        ),
                    const SizedBox(height: 12),
                  ],
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule),
                      title: const Text('Basal suggestions'),
                      subtitle: Text(basal.hasSuggestions
                          ? '${basal.segments.length} segment(s) worth reviewing'
                          : 'No changes suggested right now'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const BasalRecommendationsScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.report});
  final TherapyReport report;

  @override
  Widget build(BuildContext context) {
    final pct = ((report.avgMultiplier - 1) * 100).round();
    final text = pct.abs() < 5
        ? 'On average your insulin needs matched your settings.'
        : pct > 0
            ? 'On average you ran ~$pct% more resistant than your settings.'
            : 'On average you ran ~${pct.abs()}% more sensitive than your settings.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Avg multiplier ${report.avgMultiplier.toStringAsFixed(2)}×',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(text),
            Text('${report.days.length} days with a usable signal',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.report});
  final TherapyReport report;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = report.days;
    return LineChart(
      LineChartData(
        minY: 0.6,
        maxY: 1.5,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: numericSideTitles(
              reservedSize: 30,
              interval: 0.2,
              clipEdges: false,
              format: (v) => v.toStringAsFixed(1),
            ),
          ),
          bottomTitles:
              hiddenAxis,
          topTitles: hiddenAxis,
          rightTitles:
              hiddenAxis,
        ),
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(y: 1.0, color: cs.outline, strokeWidth: 1, dashArray: [4, 4]),
        ]),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < days.length; i++)
                FlSpot(i.toDouble(), days[i].sensitivityMultiplier),
            ],
            isCurved: true,
            barWidth: 2.5,
            color: cs.primary,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.startMinute, required this.multiplier});
  final int startMinute;
  final double multiplier;

  @override
  Widget build(BuildContext context) {
    final h = (startMinute ~/ 60).toString().padLeft(2, '0');
    final resistant = multiplier > 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 54, child: Text('$h:00')),
          Expanded(
            child: LinearProgressIndicator(
              value: ((multiplier - 0.6) / 0.9).clamp(0.0, 1.0),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              color: resistant ? Colors.orange : Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Text('${multiplier.toStringAsFixed(2)}×'),
        ],
      ),
    );
  }
}
