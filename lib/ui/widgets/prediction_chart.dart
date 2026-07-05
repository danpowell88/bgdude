import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/predictor.dart';
import '../../core/units.dart';
import '../../state/providers.dart';

/// Prediction chart: a trailing CGM trace leading into the forward forecast, with the
/// target range shaded, a glucose y-axis (with units), and a "now" marker. Showing recent
/// history means the panel is never a blank forward line (which reads as empty, especially
/// in dev mode). Hovering shows a labelled tooltip per line so it's clear which scenario
/// each value belongs to.
class PredictionChart extends ConsumerWidget {
  const PredictionChart({super.key, this.showScenarios});

  /// Force the IOB/COB/UAM/ZT scenario overlay on/off. When null, follows advanced mode.
  final bool? showScenarios;

  /// How much recent CGM history to show before "now".
  static const _historyMinutes = 150;

  /// Distinct colour per series so the legend and the multi-line hover are legible.
  static Color seriesColor(String label, ColorScheme cs) => switch (label) {
        'Predicted' => cs.primary,
        'IOB' => const Color(0xFF3D6DF2), // insulin-only
        'COB' => const Color(0xFFE08A1E), // with carbs
        'UAM' => const Color(0xFF8A5CF0), // unannounced meal
        'Zero-temp' => const Color(0xFF17A2A5), // no basal
        _ => cs.onSurfaceVariant, // CGM history
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(glucoseUnitProvider);
    final advanced = ref.watch(advancedModeProvider);

    final state = ref.watch(livePredictionStateProvider);
    if (state == null) {
      return const Center(child: Text('No CGM data yet'));
    }
    final now = state.now;

    final predictor = ref.watch(predictorProvider);
    final primary = predictor.predict(state);
    final withScenarios = showScenarios ?? advanced;
    final scenarios =
        withScenarios ? predictor.scenarioLines(state) : <PredictionLine>[];

    double toDisplay(double m) => unit == GlucoseUnit.mmol ? Mgdl(m).mmol : m;
    double xMin(DateTime t) => t.difference(now).inMinutes.toDouble();

    // Trailing CGM history (minutes are negative — before now).
    final history = [
      for (final s in ref.watch(dayDataProvider).cgm)
        if (!s.sensorWarmup &&
            s.mgdl > 0 &&
            now.difference(s.time).inMinutes <= _historyMinutes &&
            !s.time.isAfter(now))
          FlSpot(xMin(s.time), toDisplay(s.mgdl)),
    ]..sort((a, b) => a.x.compareTo(b.x));

    final cs = Theme.of(context).colorScheme;

    LineChartBarData forecast(PredictionLine line, Color color,
        {bool thick = false}) {
      return LineChartBarData(
        spots: [
          for (final p in line.points)
            FlSpot(xMin(p.time), toDisplay(p.mgdl)),
        ],
        isCurved: true,
        color: color,
        barWidth: thick ? 3 : 1.5,
        dotData: const FlDotData(show: false),
      );
    }

    // Build the bars and a parallel list of labels so the tooltip can name each line.
    final bars = <LineChartBarData>[];
    final labels = <String>[];
    bars.add(LineChartBarData(
      spots: history,
      isCurved: true,
      color: seriesColor('CGM', cs),
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
    ));
    labels.add('CGM');
    for (final l in scenarios) {
      bars.add(forecast(l, seriesColor(l.label, cs)));
      labels.add(l.label);
    }
    bars.add(forecast(primary, cs.primary, thick: true));
    labels.add('Predicted');

    // A round y-axis interval in the display unit.
    final yInterval = unit == GlucoseUnit.mmol ? 4.0 : 72.0; // ~4 mmol / ~4 mmol in mg/dL

    return LineChart(
      LineChartData(
        minX: -_historyMinutes.toDouble(),
        maxX: 240,
        minY: toDisplay(GlucoseThresholds.veryLow - 10),
        maxY: toDisplay(GlucoseThresholds.veryHigh),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: cs.outlineVariant.withValues(alpha: 0.25), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            axisNameSize: 16,
            axisNameWidget: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(unit.label,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              interval: yInterval,
              reservedSize: 30,
              getTitlesWidget: (v, meta) {
                if (v <= meta.min || v >= meta.max) return const SizedBox.shrink();
                return Text(
                  unit == GlucoseUnit.mmol
                      ? v.toStringAsFixed(0)
                      : v.round().toString(),
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 60,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final h = (v / 60).round();
                final label = v == 0 ? 'now' : (h > 0 ? '+${h}h' : '${h}h');
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
          HorizontalRangeAnnotation(
            y1: toDisplay(GlucoseThresholds.low),
            y2: toDisplay(GlucoseThresholds.high),
            color: Colors.green.withValues(alpha: 0.10),
          ),
        ]),
        extraLinesData: ExtraLinesData(verticalLines: [
          VerticalLine(
            x: 0,
            color: cs.outline,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ]),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            maxContentWidth: 220,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${_labelFor(labels, s.barIndex)}  '
                  '${_when(s.x)}  ${_fmt(s.y, unit)}',
                  TextStyle(
                    color: cs.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: cs.outline, strokeWidth: 1),
                FlDotData(
                  getDotPainter: (spot, __, ___, ____) => FlDotCirclePainter(
                      radius: 3, color: bar.color ?? cs.primary),
                ),
              ),
          ],
        ),
        lineBarsData: bars,
      ),
    );
  }

  static String _labelFor(List<String> labels, int barIndex) =>
      (barIndex >= 0 && barIndex < labels.length) ? labels[barIndex] : '';

  static String _when(double minutes) {
    final m = minutes.round();
    if (m == 0) return 'now';
    final h = m ~/ 60;
    final rem = m.abs() % 60;
    final sign = m > 0 ? '+' : '-';
    if (h == 0) return '$sign${m.abs()}m';
    return '$sign${h.abs()}h${rem > 0 ? '${rem}m' : ''}';
  }

  static String _fmt(double display, GlucoseUnit unit) =>
      '${unit == GlucoseUnit.mmol ? display.toStringAsFixed(1) : display.round()} '
      '${unit.label}';
}

/// A colour legend for [PredictionChart]. Shows the primary forecast, the trailing CGM
/// trace, and (when [scenarios] is set) each decomposed scenario line.
class PredictionChartLegend extends StatelessWidget {
  const PredictionChartLegend({super.key, this.scenarios = false});

  final bool scenarios;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = <(String, String)>[
      ('Predicted', 'best estimate'),
      ('CGM', 'recent readings'),
      if (scenarios) ...[
        ('IOB', 'insulin only'),
        ('COB', 'with carbs'),
        ('UAM', 'unannounced meal'),
        ('Zero-temp', 'basal off'),
      ],
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final (label, hint) in entries)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 14,
              height: 3,
              decoration: BoxDecoration(
                color: PredictionChart.seriesColor(label, cs),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 5),
            Text('$label — $hint',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
      ],
    );
  }
}
