/// Shared clinical glucose colours (TASK-107) so the hero, the TIR decomposition bar and
/// the events journal can't drift apart on what "low/high" looks like. Keyed off the
/// central [GlucoseThresholds].
library;

import 'package:flutter/material.dart';

import '../../core/units.dart';

class GlucoseColors {
  const GlucoseColors._();

  // Three-way palette (below / in / above range) — used by the hero, journal category
  // markers and episode arrows.
  static const Color low = Colors.red;
  static const Color inRange = Colors.green;
  static const Color high = Colors.orange;

  /// mg/dL → below/in/above-range colour, keyed off [GlucoseThresholds].
  static Color forMgdl(double mgdl) => mgdl < GlucoseThresholds.low
      ? low
      : mgdl > GlucoseThresholds.high
          ? high
          : inRange;

  // Five-band palette for the time-in-range decomposition bar, which needs darker
  // extremes to distinguish very-low/very-high from low/high.
  static final Color veryLowBand = Colors.red.shade900;
  static final Color lowBand = Colors.red.shade400;
  static final Color inRangeBand = Colors.green.shade500;
  static final Color highBand = Colors.orange.shade400;
  static final Color veryHighBand = Colors.orange.shade800;
}
