/// CGM-trace event detectors: unannounced meals, compression lows, and exercise-impact
/// windows. These feed both insights and the training pipeline (detected artifacts like
/// compression lows are *excluded* from model training labels).
library;

import 'dart:math' as math;

import '../analytics/insulin_math.dart';
import 'attribution_kernel.dart';
import '../analytics/therapy_settings.dart';
import '../core/samples.dart';

/// A detected unannounced (unbolused) meal candidate.
class MealCandidate {
  const MealCandidate({
    required this.time,
    required this.riseRateMgdlPerMin,
    required this.estimatedCarbsGrams,
    required this.confidence,
  });
  final DateTime time;
  final double riseRateMgdlPerMin;
  final double estimatedCarbsGrams;
  final double confidence;
}

/// Detects sustained unexplained glucose rise (positive ICE) not covered by recent
/// insulin, à la oref UAM. A simple, explainable alternative to a Kalman/CUSUM filter;
/// the ML meal-detector can supersede this later.
class MealDetector {
  MealDetector({
    InsulinModel? insulinModel,
    this.riseThresholdMgdlPerMin = 1.5,
    this.sustainMinutes = 15,
  }) : _iob = IobCalculator(model: insulinModel ?? InsulinModel.rapidActing);

  final IobCalculator _iob;
  final double riseThresholdMgdlPerMin;
  final int sustainMinutes;

  List<MealCandidate> detect({
    required List<CgmSample> cgm,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required TherapySettings settings,
  }) {
    final sorted = [...cgm]
      ..removeWhere((s) => s.sensorWarmup || s.isCalibration || s.mgdl <= 0)
      ..sort((a, b) => a.time.compareTo(b.time));
    final out = <MealCandidate>[];
    var sustained = 0;
    DateTime? candidateStart;
    var accumulatedRise = 0.0;

    // TASK-137: per-step facts from the shared kernel (no carb gating here —
    // an unannounced meal is exactly what this detector hunts).
    if (sorted.isEmpty) return out;
    DateTime prevTime = sorted.first.time;
    for (final step in const AttributionKernel().steps(
        sortedCgm: sorted,
        boluses: boluses,
        basal: basal,
        settings: settings,
        iob: _iob)) {
      final gap = step.gapMinutes;
      if (step.isGapBreak) {
        sustained = 0;
        candidateStart = null;
        accumulatedRise = 0;
        prevTime = step.time;
        continue;
      }
      final roc = step.observedDelta / gap;
      final seg = step.segment!;
      final insulinDrag =
          step.insulinDragPerMin; // mg/dL/min the insulin is pulling down
      final unexplainedRise = roc + insulinDrag; // add back what insulin subtracted

      if (unexplainedRise >= riseThresholdMgdlPerMin) {
        final start = candidateStart ?? prevTime;
        candidateStart = start;
        sustained += gap;
        accumulatedRise += unexplainedRise * gap;
        if (sustained >= sustainMinutes) {
          final csf = seg.isf / seg.carbRatio;
          final estCarbs = csf == 0 ? 0.0 : accumulatedRise / csf;
          out.add(MealCandidate(
            time: start,
            riseRateMgdlPerMin: unexplainedRise,
            estimatedCarbsGrams: estCarbs,
            confidence: (sustained / 45.0).clamp(0.0, 1.0),
          ));
          sustained = 0;
          candidateStart = null;
          accumulatedRise = 0;
        }
      } else {
        sustained = 0;
        candidateStart = null;
        accumulatedRise = 0;
      }
      prevTime = step.time;
    }
    return out;
  }
}

/// A detected compression-low artifact (nocturnal sensor pressure, not a true low).
class CompressionLowEvent {
  const CompressionLowEvent({
    required this.start,
    required this.nadir,
    required this.reboundMgdlPerMin,
    required this.confidence,
  });
  final DateTime start;
  final double nadir;
  final double reboundMgdlPerMin;
  final double confidence;
}

/// Flags steep nocturnal drops with rapid rebound that are inconsistent with IOB —
/// classic compression lows. Detected events are excluded from true-low analytics and
/// from training labels.
class CompressionLowDetector {
  CompressionLowDetector({
    InsulinModel? insulinModel,
    this.dropThresholdMgdlPerMin = 2.5,
    this.reboundThresholdMgdlPerMin = 2.0,
  }) : _iob = IobCalculator(model: insulinModel ?? InsulinModel.rapidActing);

  final IobCalculator _iob;
  final double dropThresholdMgdlPerMin;
  final double reboundThresholdMgdlPerMin;

  List<CompressionLowEvent> detect({
    required List<CgmSample> cgm,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required TherapySettings settings,
    required bool Function(DateTime) isAsleep,
  }) {
    final sorted = [...cgm]
      ..removeWhere((s) => s.sensorWarmup || s.isCalibration || s.mgdl <= 0)
      ..sort((a, b) => a.time.compareTo(b.time));
    final out = <CompressionLowEvent>[];

    for (var i = 2; i < sorted.length - 2; i++) {
      final cur = sorted[i];
      if (!isAsleep(cur.time)) continue;

      final preGap = cur.time.difference(sorted[i - 1].time).inMinutes;
      final postGap = sorted[i + 1].time.difference(cur.time).inMinutes;
      if (preGap <= 0 || postGap <= 0 || preGap > 15 || postGap > 15) continue;

      final dropRate = (sorted[i - 1].mgdl - cur.mgdl) / preGap; // positive = falling
      final reboundRate = (sorted[i + 1].mgdl - cur.mgdl) / postGap;

      if (dropRate < dropThresholdMgdlPerMin) continue;
      if (reboundRate < reboundThresholdMgdlPerMin) continue;

      // A real insulin-driven low wouldn't rebound sharply while IOB is high. If IOB
      // activity can't explain such a fast drop, mark as compression artifact.
      // TASK-137: the drag computation is the shared kernel piece (this
      // detector's i-1/i/i+1 shape doesn't iterate pairs).
      final insulinDrop = AttributionKernel.insulinDragPerMinAt(
        iob: _iob,
        boluses: boluses,
        basal: basal,
        segment: settings.segmentAt(cur.time),
        t: cur.time,
      ); // mg/dL/min explainable by insulin
      final unexplained = dropRate - insulinDrop;
      if (unexplained < 1.0) continue; // insulin explains it → probably real

      final conf = (math.min(dropRate, reboundRate) / 4.0).clamp(0.0, 1.0);
      out.add(CompressionLowEvent(
        start: sorted[i - 1].time,
        nadir: cur.mgdl,
        reboundMgdlPerMin: reboundRate,
        confidence: conf,
      ));
    }
    return out;
  }
}

/// The kind of CGM data-quality fault [CgmFaultDetector] flags.
enum CgmFaultKind {
  /// An implausibly large change between consecutive readings (sensor glitch,
  /// not real physiology).
  jump,

  /// Readings stuck at (near-)identical values for longer than real glucose
  /// noise would ever produce.
  flatline,

  /// The readings immediately bracketing a dropout gap — often unreliable as
  /// the sensor reconnects.
  dropoutEdge,
}

extension CgmFaultKindX on CgmFaultKind {
  String get label => switch (this) {
        CgmFaultKind.jump => 'Implausible jump',
        CgmFaultKind.flatline => 'Stuck reading',
        CgmFaultKind.dropoutEdge => 'Dropout edge',
      };
}

/// A detected CGM data-quality fault window (TASK-141) — excluded from training
/// (alongside site-failure/warm-up/compression-low annotations) and surfaced as a
/// live flag so the rest of the app can distrust a reading without duplicating the
/// detection logic.
class CgmFaultEvent {
  const CgmFaultEvent({
    required this.start,
    required this.end,
    required this.kind,
  });
  final DateTime start;
  final DateTime end;
  final CgmFaultKind kind;

  bool covers(DateTime t) => !t.isBefore(start) && !t.isAfter(end);
}

/// Flags CGM readings that are data-quality artifacts rather than real glucose
/// behaviour, distinct from [CompressionLowDetector] (a physiologically-explainable
/// pressure-low pattern): implausible jumps, stuck/flatlined values, and the
/// unreliable readings right at a dropout's edge. None of these are user-visible
/// annotations — they're algorithmic hygiene, recomputed fresh from raw CGM each
/// time rather than persisted or surfaced for confirmation.
class CgmFaultDetector {
  const CgmFaultDetector({
    this.maxPhysiologicMgdlPerMin = 4.0,
    this.flatlineWindow = const Duration(minutes: 20),
    this.flatlineToleranceMgdl = 1.0,
    this.dropoutGapMinutes = 20,
    this.dropoutEdgeMargin = const Duration(minutes: 10),
  });

  /// Real glucose essentially never moves faster than this (Dexcom/Libre's own
  /// physiologic ceiling is ~4 mg/dL/min) — a bigger implied rate between two
  /// CONSECUTIVE (gap ≤ 15 min) readings is a sensor glitch, not a real swing.
  final double maxPhysiologicMgdlPerMin;

  /// Minimum span of (near-)identical readings before it counts as a stuck
  /// sensor rather than genuinely flat glucose (which still has minor noise).
  final Duration flatlineWindow;

  /// Readings within this many mg/dL of the run's first value count as "the same"
  /// for flatline purposes.
  final double flatlineToleranceMgdl;

  /// A gap at least this long counts as a dropout (normal CGM cadence is ~5 min).
  final int dropoutGapMinutes;

  /// How far on either side of a dropout gap to mark as edge-unreliable.
  final Duration dropoutEdgeMargin;

  List<CgmFaultEvent> detect(List<CgmSample> cgm) {
    final sorted = [...cgm]
      ..removeWhere((s) => s.sensorWarmup || s.isCalibration || s.mgdl <= 0)
      ..sort((a, b) => a.time.compareTo(b.time));
    return [
      ..._jumps(sorted),
      ..._flatlines(sorted),
      ..._dropoutEdges(sorted),
    ];
  }

  List<CgmFaultEvent> _jumps(List<CgmSample> sorted) {
    final out = <CgmFaultEvent>[];
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].time.difference(sorted[i - 1].time).inMinutes;
      if (gap <= 0 || gap > 15) continue; // not consecutive enough to compare
      final rate = (sorted[i].mgdl - sorted[i - 1].mgdl).abs() / gap;
      if (rate > maxPhysiologicMgdlPerMin) {
        out.add(CgmFaultEvent(
          start: sorted[i - 1].time,
          end: sorted[i].time,
          kind: CgmFaultKind.jump,
        ));
      }
    }
    return out;
  }

  /// A run stays open while each new reading is within [flatlineToleranceMgdl] of
  /// the run's FIRST value (not just its previous neighbour) — catching sensors
  /// stuck at one value, without also flagging a slow monotonic drift that just
  /// happens to have small step-to-step deltas.
  ///
  /// A qualifying run is flagged for only its first [flatlineWindow] — not
  /// however much further it happens to continue. A stuck sensor is caught at
  /// its ONSET; a run that stays flat for hours (a real, if rare, prolonged
  /// fault, or -- far more commonly in this codebase -- a synthetic flat test
  /// fixture) must not have its entire span excluded from training, only the
  /// bounded window that earned the flag.
  List<CgmFaultEvent> _flatlines(List<CgmSample> sorted) {
    final out = <CgmFaultEvent>[];
    var start = 0;
    for (var i = 1; i <= sorted.length; i++) {
      final continues = i < sorted.length &&
          (sorted[i].mgdl - sorted[start].mgdl).abs() <= flatlineToleranceMgdl &&
          sorted[i].time.difference(sorted[i - 1].time).inMinutes <= 15;
      if (!continues) {
        final runEnd = i - 1;
        if (runEnd > start &&
            sorted[runEnd].time.difference(sorted[start].time) >=
                flatlineWindow) {
          var windowEnd = start;
          while (windowEnd < runEnd &&
              sorted[windowEnd].time.difference(sorted[start].time) <
                  flatlineWindow) {
            windowEnd++;
          }
          out.add(CgmFaultEvent(
            start: sorted[start].time,
            end: sorted[windowEnd].time,
            kind: CgmFaultKind.flatline,
          ));
        }
        start = i < sorted.length ? i : start;
      }
    }
    return out;
  }

  List<CgmFaultEvent> _dropoutEdges(List<CgmSample> sorted) {
    final out = <CgmFaultEvent>[];
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].time.difference(sorted[i - 1].time).inMinutes;
      if (gap >= dropoutGapMinutes) {
        out.add(CgmFaultEvent(
          start: sorted[i - 1].time.subtract(dropoutEdgeMargin),
          end: sorted[i].time.add(dropoutEdgeMargin),
          kind: CgmFaultKind.dropoutEdge,
        ));
      }
    }
    return out;
  }
}
