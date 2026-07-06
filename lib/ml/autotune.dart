/// Per-day sensitivity-deviation estimation (Autotune-inspired).
///
/// Derives, from one day's CGM + insulin + carb data, a single *daily sensitivity
/// multiplier* — how much stronger/weaker insulin acted than the configured settings
/// predict. This is the label the SensitivityModel regresses against. (Unlike full
/// OpenAPS Autotune it does not separate ISF vs CR vs basal; it is one scalar.)
///
/// Method:
///   * In carb-free, insulin-active windows, compare observed ΔBG to the
///     insulin-modelled ΔBG.
///   * Each contiguous ~30-min window yields its own observed/modelled ratio; the
///     day's multiplier is the *duration-weighted median* of the window multipliers,
///     so a single anomalous stretch (compression low, unlogged snack) cannot drag
///     the whole day the way a ratio-of-summed-deltas could.
///   * The result is damped toward 1 by the day's carb-free observation time.
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
  Autotune({
    InsulinModel? insulinModel,
    this.stepMinutes = 5,
    this.windowMinutes = 30,
    this.minWindowModelledDropMgdl = 2.0,
  }) : _model = insulinModel ?? InsulinModel.rapidActing;

  final InsulinModel _model;
  final int stepMinutes;

  /// Contiguous qualifying steps are grouped into windows of about this length; each
  /// window contributes one observed/modelled ratio to the day's median.
  final int windowMinutes;

  /// A window's modelled |ΔBG| must reach this to yield a ratio (divide-noise guard).
  final double minWindowModelledDropMgdl;

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
      ..removeWhere((s) => s.sensorWarmup || s.isCalibration || s.mgdl <= 0)
      ..sort((a, b) => a.time.compareTo(b.time));

    final iob = IobCalculator(model: _model);

    // Per-window multipliers: each contiguous carb-free, insulin-active stretch of
    // ~windowMinutes yields its own observed/modelled ratio. If glucose fell faster
    // than modelled, insulin was stronger than settings say → more sensitive
    // (multiplier < 1) and vice-versa.
    final windowMults = <({double mult, double weight})>[];
    var carbFreeMinutes = 0;

    var winObserved = 0.0;
    var winModelled = 0.0;
    var winMinutes = 0;

    void closeWindow() {
      if (winModelled.abs() >= minWindowModelledDropMgdl) {
        final ratio = winObserved / winModelled;
        // ratio ~1 means settings matched. Convert to a clamped multiplier.
        windowMults.add((
          mult: (2 - ratio).clamp(0.6, 1.5),
          weight: winMinutes.toDouble(),
        ));
      }
      winObserved = 0.0;
      winModelled = 0.0;
      winMinutes = 0;
    }

    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final cur = sorted[i];
      final gapMin = cur.time.difference(prev.time).inMinutes;
      if (gapMin <= 0 || gapMin > 15) {
        closeWindow(); // sensor gap breaks the contiguous stretch.
        continue;
      }

      // Only use windows with no active carb absorption.
      final carbActive = carbs.any((c) {
        final since = cur.time.difference(c.time).inMinutes;
        return since >= -stepMinutes && since <= c.absorptionMinutes;
      });
      if (carbActive) {
        closeWindow();
        continue;
      }
      carbFreeMinutes += gapMin;

      final seg = settings.segmentAt(cur.time);
      final act = iob.total(boluses, basal, cur.time).activityUnitsPerMin;
      final modelledDelta = -act * seg.isf * gapMin; // negative = drop
      final observedDelta = cur.mgdl - prev.mgdl;

      // Only attribute when insulin is meaningfully active (avoid divide noise).
      if (modelledDelta.abs() < 0.5) continue;
      winObserved += observedDelta;
      winModelled += modelledDelta;
      winMinutes += gapMin;
      if (winMinutes >= windowMinutes) closeWindow();
    }
    closeWindow();

    double mult;
    if (windowMults.isEmpty) {
      mult = 1.0;
    } else {
      // Duration-weighted median across windows: robust to a single anomalous
      // stretch, unlike a ratio of day-long sums where excursions cancel first.
      mult = _weightedMedian(windowMults);
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

  static double _weightedMedian(List<({double mult, double weight})> entries) {
    final sorted = [...entries]..sort((a, b) => a.mult.compareTo(b.mult));
    final total = sorted.fold(0.0, (s, e) => s + e.weight);
    var cum = 0.0;
    for (final e in sorted) {
      cum += e.weight;
      if (cum >= total / 2) return e.mult;
    }
    return sorted.last.mult;
  }
}
