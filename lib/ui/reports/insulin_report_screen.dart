import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reports/insulin_report.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/chart_axis.dart';
import 'report_range_picker.dart';

/// The Insulin report: daily TDD (basal + bolus) with the split and bolus behaviour.
class InsulinReportScreen extends ConsumerWidget {
  const InsulinReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(insulinReportProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Insulin report')),
      body: Column(
        children: [
          const ReportRangePicker(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not build report: $e')),
              data: (r) => r.hasData
                  ? _Body(report: r)
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No insulin history in this range yet.'),
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
  const _Body({required this.report});
  final InsulinReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            StatTile(variant: StatVariant.metric, label: 'Avg TDD', value: '${report.avgTdd.toStringAsFixed(1)} U'),
            StatTile(variant: StatVariant.metric, label: 'Basal', value: '${(report.basalFraction * 100).round()}%'),
            StatTile(variant: StatVariant.metric,
                label: 'Boluses/day',
                value: report.bolusesPerDay.toStringAsFixed(1)),
          ],
        ),
        const SizedBox(height: 16),
        Text('Daily total insulin', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(height: 200, child: _TddChart(report: report)),
        const SizedBox(height: 6),
        _Legend(),
        const SizedBox(height: 20),
        Text('Bolus behaviour', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _Row('Boluses', '${report.bolusCount}'),
        _Row('Meal boluses', '${report.mealBolusCount}'),
        _Row('Manual corrections', '${report.correctionBolusCount}'),
        _Row('Control-IQ auto-boluses', '${report.autoBolusCount}'),
        _Row('Average size', '${report.avgBolusUnits.toStringAsFixed(1)} U'),
        _Row('Average basal/day', '${report.avgBasal.toStringAsFixed(1)} U'),
        _Row('Average bolus/day', '${report.avgBolus.toStringAsFixed(1)} U'),
        const SizedBox(height: 12),
        Text('Basal is integrated from recorded rate changes and may under-count on '
            'days with sparse pump history.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 20),
        Text('Control-IQ workload', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
            'How hard the loop is compensating for you, independent of anything you '
            'changed yourself — a rising trend here is often the earliest sign that '
            'basal/ISF/carb ratio need a look.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        _Row('Auto-bolus units/day',
            '${report.avgAutoBolusUnits.toStringAsFixed(2)} U'),
        _Row('Auto-corrections/day',
            report.avgAutoCorrectionCount.toStringAsFixed(1)),
        _Row('Loop-delivered fraction',
            '${(report.loopBolusFraction * 100).toStringAsFixed(0)}% of all bolus insulin'),
        const SizedBox(height: 8),
        SizedBox(height: 80, child: _AutoBolusSparkline(report: report)),
      ],
    );
  }
}

/// TASK-151: per-day auto-bolus units, so a trend (not just an average) is
/// visible — a settings drift often shows as a gradual climb before it's
/// obvious in the averages.
class _AutoBolusSparkline extends StatelessWidget {
  const _AutoBolusSparkline({required this.report});
  final InsulinReport report;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = report.days;
    final maxUnits =
        days.fold<double>(1, (m, d) => d.autoBolusUnits > m ? d.autoBolusUnits : m);
    return LineChart(
      LineChartData(
        maxY: maxUnits * 1.15,
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < days.length; i++)
                FlSpot(i.toDouble(), days[i].autoBolusUnits),
            ],
            isCurved: false,
            color: cs.tertiary,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: cs.tertiary.withValues(alpha: 0.15)),
          ),
        ],
      ),
    );
  }
}

class _TddChart extends StatelessWidget {
  const _TddChart({required this.report});
  final InsulinReport report;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = report.days;
    final maxTdd = days.fold<double>(1, (m, d) => d.total > m ? d.total : m);
    return BarChart(
      BarChartData(
        maxY: maxTdd * 1.15,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              hiddenAxis,
          rightTitles:
              hiddenAxis,
          bottomTitles:
              hiddenAxis,
          // Y-axis: total daily insulin in units.
          leftTitles: AxisTitles(
            axisNameSize: 14,
            axisNameWidget: Text('U/day',
                style:
                    TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
            sideTitles: numericSideTitles(
              reservedSize: 28,
              interval: (maxTdd / 2).clamp(1, double.infinity),
              color: cs.onSurfaceVariant,
              format: (v) => v.toStringAsFixed(0),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: days[i].total,
                width: days.length > 45 ? 2 : 6,
                borderRadius: BorderRadius.zero,
                rodStackItems: [
                  BarChartRodStackItem(0, days[i].basal, cs.primary),
                  BarChartRodStackItem(
                      days[i].basal, days[i].total, cs.tertiary),
                ],
              ),
            ]),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, color: c),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ]);
    return Row(children: [
      dot(cs.primary, 'Basal'),
      const SizedBox(width: 16),
      dot(cs.tertiary, 'Bolus'),
    ]);
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
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
}
