import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/predictor.dart';
import '../../core/units.dart';
import '../../state/providers.dart';

/// Prediction cone: the primary forecast line with the target range shaded. In advanced
/// mode the scenario lines (IOB/COB/UAM/ZT) are overlaid.
class PredictionChart extends ConsumerWidget {
  const PredictionChart({super.key, this.showScenarios});

  /// Force the IOB/COB/UAM/ZT scenario overlay on/off. When null, follows advanced mode.
  final bool? showScenarios;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(glucoseUnitProvider);
    final advanced = ref.watch(advancedModeProvider);

    final state = ref.watch(livePredictionStateProvider);
    if (state == null) {
      return const Center(child: Text('No CGM data yet'));
    }

    final predictor = ref.watch(predictorProvider);
    final primary = predictor.predict(state);
    final withScenarios = showScenarios ?? advanced;
    final lines =
        withScenarios ? predictor.scenarioLines(state) : <PredictionLine>[];

    double toDisplay(double m) =>
        unit == GlucoseUnit.mmol ? Mgdl(m).mmol : m;

    LineChartBarData bar(PredictionLine line, Color color, {bool thick = false}) {
      final t0 = line.points.first.time;
      return LineChartBarData(
        spots: [
          for (final p in line.points)
            FlSpot(p.time.difference(t0).inMinutes.toDouble(), toDisplay(p.mgdl)),
        ],
        isCurved: true,
        color: color,
        barWidth: thick ? 3 : 1.5,
        dotData: const FlDotData(show: false),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return LineChart(
      LineChartData(
        minY: toDisplay(GlucoseThresholds.veryLow - 10),
        maxY: toDisplay(GlucoseThresholds.veryHigh),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
          HorizontalRangeAnnotation(
            y1: toDisplay(GlucoseThresholds.low),
            y2: toDisplay(GlucoseThresholds.high),
            color: Colors.green.withValues(alpha: 0.10),
          ),
        ]),
        lineBarsData: [
          for (final l in lines) bar(l, cs.outline.withValues(alpha: 0.5)),
          bar(primary, cs.primary, thick: true),
        ],
      ),
    );
  }
}
