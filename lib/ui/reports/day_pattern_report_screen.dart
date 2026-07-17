import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/units.dart';
import '../../reports/day_pattern_report.dart';
import '../../state/providers.dart';
import '../widgets/chart_axis.dart';
import 'report_range_picker.dart';

/// The Patterns report: does your glucose actually behave differently on
/// weekends vs weekdays, or in some OTHER routine-driven grouping the calendar
/// doesn't name? (TASK-154)
class DayPatternReportScreen extends ConsumerWidget {
  const DayPatternReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dayPatternReportProvider);
    final unit = ref.watch(glucoseUnitProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Patterns')),
      body: Column(
        children: [
          const ReportRangePicker(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not build report: $e')),
              data: (r) => r.hasData
                  ? _Body(report: r, unit: unit)
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Not enough CGM history in this range yet — come back '
                          'after a few days of data.',
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

class _Body extends StatelessWidget {
  const _Body({required this.report, required this.unit});
  final DayPatternReport report;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Weekday vs weekend', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('${report.dayFeatures.length} days with enough coverage to compare.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        _ClusterOverlay(clusters: report.weekdayVsWeekend, unit: unit),
        const SizedBox(height: 8),
        for (final c in report.weekdayVsWeekend) _ClusterRow(cluster: c, unit: unit),
        const SizedBox(height: 20),
        if (report.kMeansClusters != null) ...[
          Text('Learned pattern (independent of the calendar)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
              'An on-device grouping of your OWN days by how they actually behaved — '
              'not just weekday/weekend — for whatever routine (or lack of one) '
              'actually drives the difference.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          _ClusterOverlay(clusters: report.kMeansClusters!, unit: unit),
          const SizedBox(height: 8),
          for (final c in report.kMeansClusters!) _ClusterRow(cluster: c, unit: unit),
        ] else
          Text(
              'Needs at least ${DayPatternReportBuilder.minDaysForKMeans} days of '
              'history for a learned (non-calendar) grouping — '
              '${report.dayFeatures.length} so far.',
              style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ClusterRow extends StatelessWidget {
  const _ClusterRow({required this.cluster, required this.unit});
  final DayCluster cluster;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    if (cluster.dayCount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('${cluster.label}: no days in range',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(cluster.label,
                  style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(
              child: Text('${cluster.dayCount} days',
                  style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
              child: Text(
                  'Mean ${Mgdl(cluster.avgMeanMgdl).display(unit)}',
                  style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
              child: Text('TIR ${(cluster.avgTir * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Overlaid MEDIAN AGP lines per cluster — full percentile bands per cluster
/// would be too visually cluttered with 2+ clusters at once; the median alone
/// is enough to see "weekend mornings run higher"-style shape differences.
class _ClusterOverlay extends StatelessWidget {
  const _ClusterOverlay({required this.clusters, required this.unit});
  final List<DayCluster> clusters;
  final GlucoseUnit unit;

  static const _colors = [Colors.blue, Colors.orange, Colors.green];

  double _d(double mgdl) => Mgdl(mgdl).inUnit(unit);

  @override
  Widget build(BuildContext context) {
    final withData = [for (final c in clusters) if (c.agp.isNotEmpty) c];
    if (withData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Not enough data for an overlay yet.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 24,
              minY: _d(GlucoseThresholds.veryLow - 15),
              maxY: _d(GlucoseThresholds.veryHigh + 20),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: numericSideTitles(
                    reservedSize: 34,
                    clipEdges: false,
                    format: (v) => v.toStringAsFixed(0),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: numericSideTitles(
                    reservedSize: 22,
                    interval: 6,
                    clipEdges: false,
                    format: (v) => '${v.toInt()}h',
                  ),
                ),
                topTitles: hiddenAxis,
                rightTitles: hiddenAxis,
              ),
              rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
                HorizontalRangeAnnotation(
                  y1: _d(GlucoseThresholds.low),
                  y2: _d(GlucoseThresholds.high),
                  color: Colors.green.withValues(alpha: 0.10),
                ),
              ]),
              lineBarsData: [
                for (var i = 0; i < withData.length; i++)
                  LineChartBarData(
                    spots: [
                      for (final b in withData[i].agp)
                        FlSpot(b.minuteOfDay / 60.0, _d(b.median)),
                    ],
                    isCurved: true,
                    barWidth: 2.5,
                    color: _colors[i % _colors.length],
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 16,
          children: [
            for (var i = 0; i < withData.length; i++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 10, height: 10, color: _colors[i % _colors.length]),
                const SizedBox(width: 4),
                Text(withData[i].label,
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
          ],
        ),
      ],
    );
  }
}
