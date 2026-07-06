/// Shared fl_chart axis scaffolding (TASK-107). The reports and forecast charts repeated
/// the same "hide this axis" boilerplate and the same edge-clipped numeric side-axis, so
/// they live here once.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// An axis with no titles — the top/right/bottom scaffolding every chart repeats.
const AxisTitles hiddenAxis = AxisTitles(sideTitles: SideTitles(showTitles: false));

/// A numeric side-axis. [format] renders each tick; when [clipEdges] (the default), ticks
/// sitting on the exact min/max are hidden so they don't collide with the chart frame.
SideTitles numericSideTitles({
  required double reservedSize,
  required String Function(double value) format,
  double? interval,
  Color? color,
  double fontSize = 9,
  bool clipEdges = true,
}) =>
    SideTitles(
      showTitles: true,
      reservedSize: reservedSize,
      interval: interval,
      getTitlesWidget: (v, meta) {
        if (clipEdges && (v <= meta.min || v >= meta.max)) {
          return const SizedBox.shrink();
        }
        return Text(format(v), style: TextStyle(fontSize: fontSize, color: color));
      },
    );
