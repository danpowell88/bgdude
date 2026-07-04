import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/predictor.dart';
import '../../core/samples.dart';
import '../../core/units.dart';
import '../../state/providers.dart';

/// Prediction cone: the primary forecast line with the target range shaded. In advanced
/// mode the scenario lines (IOB/COB/UAM/ZT) are overlaid.
class PredictionChart extends ConsumerWidget {
  const PredictionChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(pumpSnapshotProvider).valueOrNull;
    final unit = ref.watch(glucoseUnitProvider);
    final advanced = ref.watch(advancedModeProvider);
    final settings = ref.watch(therapySettingsProvider);
    final context0 = ref.watch(sensitivityContextProvider);

    final mgdl = snapshot?.cgmMgdl?.toDouble();
    if (mgdl == null) {
      return const Center(child: Text('No CGM data yet'));
    }

    final now = snapshot!.cgmTime ?? DateTime.now();
    final state = PredictionState(
      now: now,
      currentMgdl: mgdl,
      recentRocMgdlPerMin: (snapshot.cgmTrend ?? GlucoseTrend.flat).mgdlPerMin,
      boluses: const [], // wired to the DB repository in the full data flow
      basal: const [],
      carbs: const [],
      settings: settings,
      context: context0,
    );

    final predictor = ref.watch(predictorProvider);
    final primary = predictor.predict(state);
    final lines = advanced ? predictor.scenarioLines(state) : <PredictionLine>[];

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
