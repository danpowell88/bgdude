/// The shared per-step sensitivity-attribution kernel (TASK-137). Four analyses
/// used to re-implement the same loop subtly differently — sorted CGM pairs, a
/// gap guard, a carb-active check, and the modelled-vs-observed delta from
/// `iob.total().activityUnitsPerMin * isf` — each paying an O(carbs) scan per
/// step. This kernel yields the per-step facts once; consumers keep their own
/// windowing/bucketing policies on top.
library;

import '../analytics/insulin_math.dart';
import '../analytics/therapy_settings.dart';
import '../core/samples.dart';

/// One adjacent-pair step over the sorted CGM trace.
class AttributionStep {
  const AttributionStep({
    required this.time,
    required this.gapMinutes,
    required this.isGapBreak,
    this.observedDelta = 0,
    this.modelledDelta = 0,
    this.insulinDragPerMin = 0,
    this.carbActive = false,
    this.segment,
  });

  /// The current sample's time (the step end).
  final DateTime time;
  final int gapMinutes;

  /// True when the pair spans a sensor gap (gap <= 0 or > maxGap): consumers
  /// reset their window state; the other fields are not populated.
  final bool isGapBreak;

  /// cur.mgdl − prev.mgdl over the step.
  final double observedDelta;

  /// −insulinDragPerMin × gap: what insulin activity alone should have done
  /// (negative = drop).
  final double modelledDelta;

  /// mg/dL per minute currently explainable by insulin activity (act × ISF).
  final double insulinDragPerMin;

  /// Whether any carb entry is actively absorbing at [time].
  final bool carbActive;

  /// The therapy segment at [time] (for consumers needing ISF/CR directly).
  final TherapySegment? segment;
}

class AttributionKernel {
  const AttributionKernel({this.maxGapMinutes = 15, this.stepMinutes = 5});

  final int maxGapMinutes;

  /// Slack before a carb entry within which it already counts as active
  /// (matches the historical `since >= -stepMinutes` check).
  final int stepMinutes;

  /// mg/dL per minute explainable by insulin activity at [t] — the piece the
  /// compression-low detector shares without iterating pairs.
  static double insulinDragPerMinAt({
    required IobCalculator iob,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required TherapySegment segment,
    required DateTime t,
  }) =>
      iob.total(boluses, basal, t).activityUnitsPerMin * segment.isf;

  /// Iterate adjacent CGM pairs of [sortedCgm] (must be time-sorted), yielding
  /// the per-step attribution facts. Carbs are sorted ONCE and checked through
  /// a forward window instead of an O(carbs) scan per step (TASK-137 AC#3).
  Iterable<AttributionStep> steps({
    required List<CgmSample> sortedCgm,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required TherapySettings settings,
    required IobCalculator iob,
    List<CarbEntry> carbs = const [],
  }) sync* {
    final sortedCarbs = [...carbs]..sort((a, b) => a.time.compareTo(b.time));
    var maxAbsorption = 0;
    for (final c in sortedCarbs) {
      if (c.absorptionMinutes > maxAbsorption) {
        maxAbsorption = c.absorptionMinutes;
      }
    }
    var carbLo = 0;

    bool carbActiveAt(DateTime t) {
      // Drop carbs that ended long ago even at the longest absorption; times
      // are visited in order so the pointer only moves forward.
      while (carbLo < sortedCarbs.length &&
          t.difference(sortedCarbs[carbLo].time).inMinutes > maxAbsorption) {
        carbLo++;
      }
      for (var k = carbLo; k < sortedCarbs.length; k++) {
        final since = t.difference(sortedCarbs[k].time).inMinutes;
        if (since < -stepMinutes) break; // sorted: the rest are further future
        if (since <= sortedCarbs[k].absorptionMinutes) return true;
      }
      return false;
    }

    for (var i = 1; i < sortedCgm.length; i++) {
      final prev = sortedCgm[i - 1];
      final cur = sortedCgm[i];
      final gapMin = cur.time.difference(prev.time).inMinutes;
      if (gapMin <= 0 || gapMin > maxGapMinutes) {
        yield AttributionStep(
            time: cur.time, gapMinutes: gapMin, isGapBreak: true);
        continue;
      }
      final seg = settings.segmentAt(cur.time);
      final drag = insulinDragPerMinAt(
          iob: iob, boluses: boluses, basal: basal, segment: seg, t: cur.time);
      yield AttributionStep(
        time: cur.time,
        gapMinutes: gapMin,
        isGapBreak: false,
        observedDelta: cur.mgdl - prev.mgdl,
        modelledDelta: -drag * gapMin,
        insulinDragPerMin: drag,
        carbActive: carbActiveAt(cur.time),
        segment: seg,
      );
    }
  }
}
