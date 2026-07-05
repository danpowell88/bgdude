import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/carb_math.dart';
import '../../analytics/insulin_math.dart';
import '../../state/providers.dart';

/// Projects **insulin- and carbs-on-board and the scheduled basal** forward over the next
/// few hours, so the glucose forecast has context: you can see the IOB and COB that are
/// driving it fall away, and where the basal steps are.
///
/// One compact chart with a dual axis — insulin on the left (U for IOB, U/h for basal,
/// which share the same small magnitude), carbs on the right (g). COB is drawn against the
/// right axis; the tooltip reports each series in its own unit.
class OnBoardForecastChart extends ConsumerWidget {
  const OnBoardForecastChart({super.key, this.horizonMinutes = 240});

  final int horizonMinutes;

  static const _iobColor = Color(0xFF3D6DF2);
  static const _cobColor = Color(0xFFE08A1E);
  static const _basalColor = Color(0xFF17A2A5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(livePredictionStateProvider);
    if (state == null) return const SizedBox.shrink();
    final now = state.now;
    const iobCalc = IobCalculator();
    const carbModel = CarbModel();

    final iob = <FlSpot>[];
    final cob = <FlSpot>[];
    final basal = <FlSpot>[];
    for (var t = 0; t <= horizonMinutes; t += 10) {
      final at = now.add(Duration(minutes: t));
      final x = t.toDouble();
      iob.add(FlSpot(x, iobCalc.total(state.boluses, state.basal, at).units));
      cob.add(FlSpot(x, carbModel.cob(state.carbs, at)));
      basal.add(FlSpot(x, state.settings.segmentAt(at).basalUnitsPerHour));
    }

    double maxOf(List<FlSpot> s) => s.fold(0.0, (m, p) => p.y > m ? p.y : m);
    // Insulin (left) axis spans IOB and basal; carbs (right) axis spans COB.
    final maxInsulin = [maxOf(iob), maxOf(basal), 1.0].reduce((a, b) => a > b ? a : b);
    final maxCarb = [maxOf(cob), 10.0].reduce((a, b) => a > b ? a : b);
    // COB is drawn on the insulin scale then read back as grams on the right axis.
    final carbToInsulin = maxInsulin / maxCarb;

    final cs = Theme.of(context).colorScheme;

    LineChartBarData area(List<FlSpot> spots, Color color) => LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
              show: true, color: color.withValues(alpha: 0.12)),
        );

    final bars = <LineChartBarData>[
      area(iob, _iobColor), // 0
      area([for (final p in cob) FlSpot(p.x, p.y * carbToInsulin)],
          _cobColor), // 1 (COB scaled onto the insulin axis)
      LineChartBarData(
        spots: basal,
        isStepLineChart: true,
        color: _basalColor,
        barWidth: 1.5,
        dotData: const FlDotData(show: false),
      ), // 2
    ];

    String tip(int bar, double y) => switch (bar) {
          0 => 'IOB ${y.toStringAsFixed(2)} U',
          1 => 'COB ${(y / carbToInsulin).round()} g',
          _ => 'Basal ${y.toStringAsFixed(2)} U/h',
        };

    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: horizonMinutes.toDouble(),
          minY: 0,
          maxY: maxInsulin * 1.1,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              axisNameSize: 14,
              axisNameWidget: const Text('U · U/h',
                  style: TextStyle(fontSize: 9, color: _iobColor)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: maxInsulin / 2,
                getTitlesWidget: (v, meta) =>
                    (v <= meta.min || v >= meta.max)
                        ? const SizedBox.shrink()
                        : Text(v.toStringAsFixed(1),
                            style: TextStyle(
                                fontSize: 9, color: cs.onSurfaceVariant)),
              ),
            ),
            rightTitles: AxisTitles(
              axisNameSize: 14,
              axisNameWidget: const Text('g',
                  style: TextStyle(fontSize: 9, color: _cobColor)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: maxInsulin / 2,
                getTitlesWidget: (v, meta) =>
                    (v <= meta.min || v >= meta.max)
                        ? const SizedBox.shrink()
                        : Text((v / carbToInsulin).round().toString(),
                            style: TextStyle(
                                fontSize: 9, color: cs.onSurfaceVariant)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 60,
                reservedSize: 18,
                getTitlesWidget: (v, _) {
                  final h = (v / 60).round();
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(v == 0 ? 'now' : '+${h}h',
                        style: const TextStyle(fontSize: 9)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => cs.inverseSurface,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    tip(s.barIndex, s.y),
                    TextStyle(
                        color: cs.onInverseSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          lineBarsData: bars,
        ),
      ),
    );
  }
}

/// Legend + units for [OnBoardForecastChart].
class OnBoardForecastLegend extends StatelessWidget {
  const OnBoardForecastLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget chip(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 14,
                height: 3,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        );
    return Wrap(spacing: 12, runSpacing: 4, children: [
      chip(OnBoardForecastChart._iobColor, 'IOB (U)'),
      chip(OnBoardForecastChart._cobColor, 'COB (g)'),
      chip(OnBoardForecastChart._basalColor, 'Basal (U/h)'),
    ]);
  }
}
