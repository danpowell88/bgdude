/// Autotune-style parameter learning.
///
/// Estimates, from historical CGM + insulin + carb data, how the user's real ISF / CR
/// / basal needs deviate from their configured settings — and derives the per-day
/// "sensitivity deviation" label the SensitivityModel regresses against.
///
/// This is a simplified, transparent adaptation of the OpenAPS autotune idea:
///   * Compute Insulin Counteraction Effect (ICE) = observed ΔBG − insulin-modelled ΔBG.
///   * In carb-free windows, residual deviation is attributed to basal/ISF mismatch.
///   * Aggregate deviations into a daily multiplier, damped so noise can't swing it.
///
/// Deliberately conservative: it *suggests* parameter deltas and produces labels for
/// the ML layer; it never writes to the pump.
library;

import '../analytics/insulin_math.dart';
import '../analytics/therapy_settings.dart';
import '../core/samples.dart';

class DayResult {
  const DayResult({
    required this.day,
    required this.sensitivityMultiplier,
    required this.sampleCount,
    required this.carbFreeMinutes,
  });

  final DateTime day;

  /// >1 = needed more insulin than settings (resistant); <1 = more sensitive.
  final double sensitivityMultiplier;
  final int sampleCount;
  final int carbFreeMinutes;

  /// Confidence in this day's estimate: needs enough carb-free observation.
  double get confidence => (carbFreeMinutes / 480.0).clamp(0.0, 1.0);
}

class Autotune {
  Autotune({InsulinModel? insulinModel, this.stepMinutes = 5})
      : _model = insulinModel ?? InsulinModel.rapidActing;

  final InsulinModel _model;
  final int stepMinutes;

  /// Estimate the sensitivity multiplier for one day from its data.
  DayResult analyseDay({
    required DateTime day,
    required List<CgmSample> cgm,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required List<CarbEntry> carbs,
    required TherapySettings settings,
  }) {
    final sorted = [...cgm]
      ..removeWhere((s) => s.sensorWarmup || s.mgdl <= 0)
      ..sort((a, b) => a.time.compareTo(b.time));

    final iob = IobCalculator(model: _model);

    // Sum, over carb-free steps, the ratio of observed insulin effect to modelled
    // insulin effect. If glucose fell faster than modelled, insulin was stronger than
    // settings say → more sensitive (multiplier < 1) and vice-versa.
    var observedDrop = 0.0;
    var modelledDrop = 0.0;
    var carbFreeMinutes = 0;

    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final cur = sorted[i];
      final gapMin = cur.time.difference(prev.time).inMinutes;
      if (gapMin <= 0 || gapMin > 15) continue; // skip gaps

      // Only use windows with no active carb absorption.
      final carbActive = carbs.any((c) {
        final since = cur.time.difference(c.time).inMinutes;
        return since >= -stepMinutes && since <= c.absorptionMinutes;
      });
      if (carbActive) continue;
      carbFreeMinutes += gapMin;

      final seg = settings.segmentAt(cur.time);
      final act = iob.total(boluses, basal, cur.time).activityUnitsPerMin;
      final modelledDelta = -act * seg.isf * gapMin; // negative = drop
      final observedDelta = cur.mgdl - prev.mgdl;

      // Only attribute when insulin is meaningfully active (avoid divide noise).
      if (modelledDelta.abs() < 0.5) continue;
      observedDrop += observedDelta;
      modelledDrop += modelledDelta;
    }

    double mult;
    if (modelledDrop.abs() < 1e-6) {
      mult = 1.0;
    } else {
      // If observed drop exceeds modelled (more negative), insulin over-performed →
      // more sensitive → multiplier < 1.
      final ratio = observedDrop / modelledDrop;
      // ratio ~1 means settings matched. Convert to a damped multiplier.
      mult = (2 - ratio).clamp(0.6, 1.5);
      // Damp toward 1 by confidence-of-day.
      final conf = (carbFreeMinutes / 480.0).clamp(0.0, 1.0);
      mult = 1 + (mult - 1) * conf;
    }

    return DayResult(
      day: DateTime(day.year, day.month, day.day),
      sensitivityMultiplier: mult,
      sampleCount: sorted.length,
      carbFreeMinutes: carbFreeMinutes,
    );
  }
}
