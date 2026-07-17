import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/metrics.dart';
import '../../core/units.dart';
import '../../core/time_format.dart';
import '../../reports/clinic_prep.dart';
import '../../reports/glucose_report.dart';
import '../../reports/report_exporter.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/glucose_colors.dart';
import '../widgets/chart_axis.dart';
import '../widgets/event_marker_bar.dart';
import '../timeline_screen.dart' show explainDayEvent;
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
            icon: const Icon(Icons.medical_information_outlined),
            tooltip: 'Clinic-visit prep',
            onPressed: async.valueOrNull == null
                ? null
                : () {
                    final bundle = async.value!;
                    if (!bundle.report.hasData) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('No data to prepare for this range.')));
                      return;
                    }
                    final prep = const ClinicPrepBuilder()
                        .build(report: bundle.report, unit: unit);
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => _ClinicPrepSheet(
                          prep: prep, generatedAt: bundle.report.generatedAt),
                    );
                  },
          ),
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
              error: (e, _) =>
                  Center(child: Text('Could not build report: $e')),
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
        if (m.variabilityHigh)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _Banner(
              'Glucose variability is high (CV ${m.cvPercent.round()}% ≥ 36%) — the '
              'consensus marker for a raised hypo risk. Steadier days lower it.',
            ),
          ),
        const SizedBox(height: 16),
        _TirBar(m: m),
        const SizedBox(height: 16),
        _RiskCard(m: m),
        const SizedBox(height: 20),
        Text('Ambulatory glucose profile',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(height: 220, child: _AgpChart(report: report, unit: unit)),
        const SizedBox(height: 8),
        Text(
            'Median with 25–75% (dark) and 5–95% (light) bands; green = target. '
            'Icons mark today\'s flagged events by time of day — tap one to explain.',
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
        StatTile(
            variant: StatVariant.metric,
            label: 'Mean',
            value: '${Mgdl(m.meanMgdl).display(unit)} ${unit.label}'),
        StatTile(
            variant: StatVariant.metric,
            label: 'GMI',
            value: '${m.gmi.toStringAsFixed(1)}%'),
        StatTile(
            variant: StatVariant.metric,
            label: 'CV',
            value: '${m.cvPercent.toStringAsFixed(0)}%'),
        StatTile(
            variant: StatVariant.metric,
            label: 'TIR',
            value: '${(m.timeInRange * 100).round()}%'),
      ],
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.m});
  final GlucoseMetrics m;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Risk indices', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                StatTile(
                    variant: StatVariant.metric,
                    label: 'GRI',
                    value: m.gri.round().toString()),
                StatTile(
                    variant: StatVariant.metric,
                    label: 'LBGI',
                    value: m.lbgi.toStringAsFixed(1)),
                StatTile(
                    variant: StatVariant.metric,
                    label: 'HBGI',
                    value: m.hbgi.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'GRI 0–100 (lower better). LBGI hypo risk: <2.5 low, >5 high. '
              'HBGI hyper risk: <5 low, >10 high.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TirBar extends StatelessWidget {
  const _TirBar({required this.m});
  final GlucoseMetrics m;

  @override
  Widget build(BuildContext context) {
    final b = m.bands;
    final inRange = b.inRange;
    final segments = <(double, Color)>[
      (b.veryLow, GlucoseColors.veryLowBand),
      (b.low, GlucoseColors.lowBand),
      (b.inRange, GlucoseColors.inRangeBand),
      (b.high, GlucoseColors.highBand),
      (b.veryHigh, GlucoseColors.veryHighBand),
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
          'Tight 70–140 ${(m.timeInTightRange * 100).round()}%  ·  '
          'Below ${(m.timeBelow70 * 100).round()}%  ·  '
          'Above ${(m.timeAbove180 * 100).round()}%',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AgpChart extends ConsumerWidget {
  const _AgpChart({required this.report, required this.unit});
  final GlucoseReport report;
  final GlucoseUnit unit;

  double _d(double mgdl) => Mgdl(mgdl).inUnit(unit);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final agp = report.agp;
    if (agp.length < 2) {
      return const Center(child: Text('Not enough data for an AGP curve.'));
    }
    double x(int minuteOfDay) => minuteOfDay / 60.0;
    LineChartBarData line(double Function(AgpBucket b) sel,
            {double width = 0}) =>
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

    final chart = LineChart(
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
        lineBarsData: bars,
        betweenBarsData: [
          BetweenBarsData(
              fromIndex: 0,
              toIndex: 1,
              color: cs.primary.withValues(alpha: 0.12)),
          BetweenBarsData(
              fromIndex: 2,
              toIndex: 3,
              color: cs.primary.withValues(alpha: 0.25)),
        ],
      ),
    );

    // TASK-155: today's explainable events, positioned by time-of-day against the
    // pooled AGP curve — the AGP itself spans the whole report range, but events are
    // only detected for today (EventBuilder runs per-day), so this shows where
    // today's flagged moments land relative to the typical-day profile.
    final events = ref.watch(dayEventsProvider);

    return Column(
      children: [
        Expanded(child: chart),
        EventMarkerBar(
          events: events,
          minX: 0,
          maxX: 24,
          xForTime: (t) => t.hour + t.minute / 60.0,
          leftAxisWidth: 34,
          onTap: (e) => explainDayEvent(context, ref, e),
        ),
      ],
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
        Text(
            '${report.lowEpisodes.length} low · ${report.highEpisodes.length} high',
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
                color: e.isLow ? GlucoseColors.low : GlucoseColors.high,
              ),
              title: Text(
                  '${e.isLow ? 'Low' : 'High'} to ${Mgdl(e.extremeMgdl).display(unit)} ${unit.label}'),
              subtitle: Text(
                  '${formatShortDateTime(e.start)} · ${e.duration.inMinutes} min'),
            ),
      ],
    );
  }
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

/// Clinic-visit prep (§4-4.4): a plain-language summary plus suggested questions, with a
/// one-tap "Share PDF" that reuses the report PDF pipeline. Template-generated — no model
/// needed.
class _ClinicPrepSheet extends StatelessWidget {
  const _ClinicPrepSheet({required this.prep, required this.generatedAt});
  final ClinicPrep prep;
  final DateTime generatedAt;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      // TASK-228: edge-to-edge means the bottom system inset (gesture nav bar) is
      // separate from the sheet's own fixed padding -- without SafeArea the last
      // items (Share PDF button, disclaimer text) could sit under the gesture bar.
      builder: (context, controller) => SafeArea(
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('Clinic-visit prep', style: text.titleLarge),
            Text(prep.rangeLabel, style: text.labelMedium),
            const SizedBox(height: 12),
            Text('Summary', style: text.titleSmall),
            const SizedBox(height: 4),
            Text(prep.summary),
            const SizedBox(height: 16),
            Text('Questions to ask', style: text.titleSmall),
            const SizedBox(height: 4),
            for (final q in prep.questions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(q)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.ios_share),
              label: const Text('Share PDF'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await const ReportExporter()
                      .shareClinicPrep(prep, generatedAt);
                } catch (e) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('Share failed: $e')));
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Template-generated from your data — a conversation starter, not clinical '
              'advice. Targets referenced are the ADA/ATTD consensus.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
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
