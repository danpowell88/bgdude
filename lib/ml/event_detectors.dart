/// CGM-trace event detectors: unannounced meals, compression lows, and exercise-impact
/// windows. These feed both insights and the training pipeline (detected artifacts like
/// compression lows are *excluded* from model training labels).
library;

import 'dart:math' as math;

import '../analytics/insulin_math.dart';
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

    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final cur = sorted[i];
      final gap = cur.time.difference(prev.time).inMinutes;
      if (gap <= 0 || gap > 15) {
        sustained = 0;
        candidateStart = null;
        accumulatedRise = 0;
        continue;
      }
      final roc = (cur.mgdl - prev.mgdl) / gap;
      final seg = settings.segmentAt(cur.time);
      final act = _iob.total(boluses, basal, cur.time).activityUnitsPerMin;
      final insulinDrag = act * seg.isf; // mg/dL/min the insulin is pulling down
      final unexplainedRise = roc + insulinDrag; // add back what insulin subtracted

      if (unexplainedRise >= riseThresholdMgdlPerMin) {
        final start = candidateStart ?? prev.time;
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
      final seg = settings.segmentAt(cur.time);
      final act = _iob.total(boluses, basal, cur.time).activityUnitsPerMin;
      final insulinDrop = act * seg.isf; // mg/dL/min explainable by insulin
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
