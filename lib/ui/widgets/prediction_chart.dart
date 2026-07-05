import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/predictor.dart';
import '../../core/units.dart';
import '../../state/providers.dart';

/// Prediction chart: a trailing CGM trace leading into the forward forecast, with the
/// target range shaded and a "now" marker. Showing recent history means the panel is
/// never a blank forward line (which read as empty, especially in dev mode), and a styled
/// touch tooltip makes hovering the lines legible.
class PredictionChart extends ConsumerWidget {
  const PredictionChart({super.key, this.showScenarios});

  /// Force the IOB/COB/UAM/ZT scenario overlay on/off. When null, follows advanced mode.
  final bool? showScenarios;

  /// How much recent CGM history to show before "now".
  static const _historyMinutes = 150;

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

    final cs = Theme.of(context).colorScheme;
    final historyBar = LineChartBarData(
      spots: history,
      isCurved: true,
      color: cs.onSurfaceVariant,
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
    );

    return LineChart(
      LineChartData(
        minX: -_historyMinutes.toDouble(),
        maxX: 240,
        minY: toDisplay(GlucoseThresholds.veryLow - 10),
        maxY: toDisplay(GlucoseThresholds.veryHigh),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
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
        lineBarsData: [
          historyBar,
          for (final l in scenarios)
            forecast(l, cs.outline.withValues(alpha: 0.5)),
          forecast(primary, cs.primary, thick: true),
        ],
      ),
    );
  }

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
