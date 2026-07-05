import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/metrics.dart';
import '../../core/units.dart';
import '../../reports/glucose_report.dart';
import '../../reports/report_exporter.dart';
import '../../state/providers.dart';
import 'report_range_picker.dart';

/// The Glucose report: AGP, time-in-range, key metrics, and episodes over the selected
/// range — built from real, confirmed data, exportable as PDF + CSV.
class GlucoseReportScreen extends ConsumerWidget {
  const GlucoseReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(glucoseUnitProvider);
    final async = ref.watch(glucoseReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Glucose report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export PDF + CSV',
            onPressed: async.valueOrNull == null
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final bundle = async.value!;
                    if (!bundle.report.hasData) {
                      messenger.showSnackBar(const SnackBar(
                          content: Text('No data to export for this range.')));
                      return;
                    }
                    try {
                      await const ReportExporter().shareGlucoseReport(
                        report: bundle.report,
                        confirmed: bundle.confirmed,
                        unit: unit,
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                          SnackBar(content: Text('Export failed: $e')));
                    }
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          const ReportRangePicker(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not build report: $e')),
              data: (bundle) => bundle.report.hasData
                  ? _ReportBody(report: bundle.report, unit: unit)
                  : const _NoData(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report, required this.unit});
  final GlucoseReport report;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    final m = report.metrics;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${report.range.label} · ${report.daysWithData} days with data',
            style: Theme.of(context).textTheme.labelLarge),
        if (!m.sufficient)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _Banner(
              '${(m.activeFraction * 100).round()}% CGM active — interpret with '
              'caution (a valid AGP wants ≥14 days and ≥70% active data).',
            ),
          ),
        const SizedBox(height: 12),
        _MetricsRow(m: m, unit: unit),
        const SizedBox(height: 16),
        _TirBar(m: m),
        const SizedBox(height: 20),
        Text('Ambulatory glucose profile',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(height: 220, child: _AgpChart(report: report, unit: unit)),
        const SizedBox(height: 8),
        Text('Median with 25–75% (dark) and 5–95% (light) bands; green = target.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 20),
        _Episodes(report: report, unit: unit),
        if (report.excludedSampleCount > 0) ...[
          const SizedBox(height: 16),
          Text(
            '${report.excludedSampleCount} sensor-artifact readings (warm-up / '
            'confirmed compression lows) were excluded.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.m, required this.unit});
  final GlucoseMetrics m;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Metric(label: 'Mean', value: '${Mgdl(m.meanMgdl).display(unit)} ${unit.label}'),
        _Metric(label: 'GMI', value: '${m.gmi.toStringAsFixed(1)}%'),
        _Metric(label: 'CV', value: '${m.cvPercent.toStringAsFixed(0)}%'),
        _Metric(label: 'TIR', value: '${(m.timeInRange * 100).round()}%'),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _TirBar extends StatelessWidget {
  const _TirBar({required this.m});
  final GlucoseMetrics m;

  @override
  Widget build(BuildContext context) {
    final veryLow = m.timeBelow54;
    final low = m.timeBelow70 - veryLow;
    final inRange = m.timeInRange;
    final high = m.timeAbove180 - m.timeAbove250;
    final veryHigh = m.timeAbove250;
    final segments = <(double, Color)>[
      (veryLow, Colors.red.shade900),
      (low, Colors.red.shade400),
      (inRange, Colors.green.shade500),
      (high, Colors.orange.shade400),
      (veryHigh, Colors.orange.shade800),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              for (final (frac, color) in segments)
                if (frac > 0)
                  Expanded(
                    flex: (frac * 1000).round(),
                    child: Container(height: 24, color: color),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'In range ${(inRange * 100).round()}%  ·  '
          'Below ${(m.timeBelow70 * 100).round()}%  ·  '
          'Above ${(m.timeAbove180 * 100).round()}%',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AgpChart extends StatelessWidget {
  const _AgpChart({required this.report, required this.unit});
  final GlucoseReport report;
  final GlucoseUnit unit;

  double _d(double mgdl) => unit == GlucoseUnit.mmol ? Mgdl(mgdl).mmol : mgdl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final agp = report.agp;
    if (agp.length < 2) {
      return const Center(child: Text('Not enough data for an AGP curve.'));
    }
    double x(int minuteOfDay) => minuteOfDay / 60.0;
    LineChartBarData line(double Function(AgpBucket b) sel, {double width = 0}) =>
        LineChartBarData(
          spots: [for (final b in agp) FlSpot(x(b.minuteOfDay), _d(sel(b)))],
          isCurved: true,
          barWidth: width,
          color: cs.primary,
          dotData: const FlDotData(show: false),
        );

    // Order: p05, p95, p25, p75, median → indices 0..4 for betweenBarsData.
    final bars = [
      line((b) => b.p05),
      line((b) => b.p95),
      line((b) => b.p25),
      line((b) => b.p75),
      line((b) => b.median, width: 3),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 24,
        minY: _d(GlucoseThresholds.veryLow - 15),
        maxY: _d(GlucoseThresholds.veryHigh + 20),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 9)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 6,
              getTitlesWidget: (v, meta) => Text('${v.toInt()}h',
                  style: const TextStyle(fontSize: 9)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
          HorizontalRangeAnnotation(
            y1: _d(GlucoseThresholds.low),
            y2: _d(GlucoseThresholds.high),
            color: Colors.green.withValues(alpha: 0.10),
          ),
        ]),
        lineBarsData: bars,
        betweenBarsData: [
          BetweenBarsData(
              fromIndex: 0, toIndex: 1, color: cs.primary.withValues(alpha: 0.12)),
          BetweenBarsData(
              fromIndex: 2, toIndex: 3, color: cs.primary.withValues(alpha: 0.25)),
        ],
      ),
    );
  }
}

class _Episodes extends StatelessWidget {
  const _Episodes({required this.report, required this.unit});
  final GlucoseReport report;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    final all = [...report.lowEpisodes, ...report.highEpisodes]
      ..sort((a, b) => b.start.compareTo(a.start));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Episodes', style: Theme.of(context).textTheme.titleMedium),
        Text('${report.lowEpisodes.length} low · ${report.highEpisodes.length} high',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        if (all.isEmpty)
          const Text('No hypo/hyper episodes ≥15 min — nicely steady.')
        else
          for (final e in all.take(12))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                e.isLow ? Icons.arrow_downward : Icons.arrow_upward,
                color: e.isLow ? Colors.red : Colors.orange,
              ),
              title: Text(
                  '${e.isLow ? 'Low' : 'High'} to ${Mgdl(e.extremeMgdl).display(unit)} ${unit.label}'),
              subtitle: Text(
                  '${_fmt(e.start)} · ${e.duration.inMinutes} min'),
            ),
      ],
    );
  }

  static String _fmt(DateTime d) =>
      '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Banner extends StatelessWidget {
  const _Banner(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No confirmed CGM data in this range yet.',
              textAlign: TextAlign.center),
        ),
      );
}
