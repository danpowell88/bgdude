import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chart_axis.dart';
import 'event_marker_bar.dart';
import '../../analytics/predictor.dart';
import '../../core/samples.dart';
import '../../core/units.dart';
import '../../state/providers.dart';
import '../timeline_screen.dart' show explainDayEvent;

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
        // Issue #77: distinct from the CGM trace, and from every forecast line — a
        // finger-prick is a different kind of measurement, not another scenario.
        'Fingerstick' => const Color(0xFFD64550),
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

    double toDisplay(double m) => Mgdl(m).inUnit(unit);
    double xMin(DateTime t) => t.difference(now).inMinutes.toDouble();

    // Trailing history (minutes are negative — before now), split by source.
    //
    // Issue #77: finger-pricks used to be drawn into the same line as the sensor, so a
    // meter reading that disagreed with the sensor appeared as a sharp kink in the CGM
    // trace — indistinguishable from the sensor itself having moved. They are separate
    // measurements and are now drawn as separate marks.
    final recent = [
      for (final s in ref.watch(dayDataProvider).cgm)
        if (!s.sensorWarmup &&
            s.mgdl > 0 &&
            now.difference(s.time).inMinutes <= _historyMinutes &&
            !s.time.isAfter(now))
          s,
    ];
    final history = [
      for (final s in recent)
        if (!isFingerstick(s)) FlSpot(xMin(s.time), toDisplay(s.mgdl)),
    ]..sort((a, b) => a.x.compareTo(b.x));
    final fingersticks = [
      for (final s in recent)
        if (isFingerstick(s)) FlSpot(xMin(s.time), toDisplay(s.mgdl)),
    ]..sort((a, b) => a.x.compareTo(b.x));

    final cs = Theme.of(context).colorScheme;

    LineChartBarData forecast(PredictionLine line, Color color,
        {bool thick = false}) {
      return LineChartBarData(
        spots: [
          for (final p in line.points) FlSpot(xMin(p.time), toDisplay(p.mgdl)),
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
    if (fingersticks.isNotEmpty) {
      // Marks only, no connecting line: consecutive finger-pricks hours apart are not
      // a trace, and joining them would imply readings that were never taken.
      bars.add(LineChartBarData(
        spots: fingersticks,
        color: seriesColor('Fingerstick', cs),
        barWidth: 0,
        dotData: FlDotData(
          getDotPainter: (spot, _, __, ___) => FlDotSquarePainter(
            size: 7,
            color: seriesColor('Fingerstick', cs),
            strokeWidth: 1.5,
            strokeColor: cs.surface,
          ),
        ),
      ));
      labels.add('Fingerstick');
    }
    for (final l in scenarios) {
      bars.add(forecast(l, seriesColor(l.label, cs)));
      labels.add(l.label);
    }
    bars.add(forecast(primary, cs.primary, thick: true));
    labels.add('Predicted');

    // A round y-axis interval in the display unit.
    final yInterval =
        unit == GlucoseUnit.mmol ? 4.0 : 72.0; // ~4 mmol / ~4 mmol in mg/dL

    // TASK-155: markers for today's explainable events (highs/lows/detected rises/
    // compression lows), aligned to this chart's own x-domain (minutes-from-now) so
    // a curve's shape can be read against what caused it.
    final events = ref.watch(dayEventsProvider);

    final chart = LineChart(
      LineChartData(
        minX: -_historyMinutes.toDouble(),
        maxX: 240,
        minY: toDisplay(GlucoseThresholds.veryLow - 10),
        maxY: toDisplay(GlucoseThresholds.veryHigh),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.25), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: hiddenAxis,
          rightTitles: hiddenAxis,
          leftTitles: AxisTitles(
            axisNameSize: 16,
            axisNameWidget: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(unit.label,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ),
            sideTitles: numericSideTitles(
              reservedSize: 30,
              interval: yInterval,
              fontSize: 10,
              color: cs.onSurfaceVariant,
              format: (v) => unit == GlucoseUnit.mmol
                  ? v.toStringAsFixed(0)
                  : v.round().toString(),
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
                  '${labelForBarIndex(labels, s.barIndex)}  '
                  '${minutesFromNowLabel(s.x)}  ${formatDisplayValue(s.y, unit)}',
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

    return Column(
      children: [
        Expanded(child: chart),
        EventMarkerBar(
          events: events,
          minX: -_historyMinutes.toDouble(),
          maxX: 240,
          xForTime: xMin,
          leftAxisWidth: 30,
          onTap: (e) => explainDayEvent(context, ref, e),
        ),
      ],
    );
  }

  /// Whether a reading came from a finger-prick meter rather than the sensor.
  ///
  /// Both the explicit calibration flag and the meter source count: a reading entered
  /// to calibrate and one imported from a Bluetooth meter are the same kind of
  /// measurement, and only one of the two flags is set depending on how it arrived.
  @visibleForTesting
  static bool isFingerstick(CgmSample s) =>
      s.isCalibration || s.source == GlucoseSource.meter;

  /// The series label for a hovered spot's bar index (tooltip line). Exposed for
  /// testing the tooltip's label lookup in isolation from the chart widget tree.
  @visibleForTesting
  static String labelForBarIndex(List<String> labels, int barIndex) =>
      (barIndex >= 0 && barIndex < labels.length) ? labels[barIndex] : '';

  /// Formats an x-axis value (minutes from now) as a relative time label, e.g.
  /// `now`, `+1h30m`, `-45m`. Exposed for testing the tooltip's time formatting.
  @visibleForTesting
  static String minutesFromNowLabel(double minutes) {
    final m = minutes.round();
    if (m == 0) return 'now';
    final h = m ~/ 60;
    final rem = m.abs() % 60;
    final sign = m > 0 ? '+' : '-';
    if (h == 0) return '$sign${m.abs()}m';
    return '$sign${h.abs()}h${rem > 0 ? '${rem}m' : ''}';
  }

  /// Formats a display-unit glucose value with its unit suffix, matching the
  /// unit's own precision convention (1 decimal for mmol/L, whole for mg/dL).
  /// Exposed for testing the tooltip's value formatting.
  @visibleForTesting
  static String formatDisplayValue(double display, GlucoseUnit unit) =>
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
      ('Fingerstick', 'meter reading'),
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
