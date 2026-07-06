/// Time-of-day insulin-sensitivity learning.
///
/// Extends the Autotune-style *daily* sensitivity estimate (`autotune.dart`) to a
/// time-of-day profile: dawn phenomenon, evening resistance, post-lunch sensitivity,
/// etc., learned from the user's own history. The mechanism is identical to
/// `Autotune.analyseDay` — in carb-free windows, compare the observed glucose change
/// against the insulin-modelled change — but deviations are accumulated into
/// [bucketCount] time-of-day buckets (default 8 × 3 h) instead of one per-day total.
///
/// Aggregation across days is deliberately robust and conservative:
///   * per bucket, the multiplier is the *median* of the per-day samples, so a single
///     weird day (site failure, unlogged meal) can't drag a bucket;
///   * the IQR of those samples drives the bucket's confidence — a bucket whose days
///     disagree is not trusted;
///   * a bucket without enough total carb-free observation time stays neutral;
///   * with fewer than [minDays] days of history the whole profile stays neutral.
///
/// The resulting [TimeOfDayProfile] interpolates smoothly (and circularly — 24 h
/// wraps) between bucket midpoints, and combines with the daily context from
/// `sensitivity_model.dart` via [TimeOfDayProfile.contextAt]. Like everything in
/// `ml/`, this only ever produces *suggestions* — it never writes to the pump.
library;

import 'dart:math' as math;

import '../analytics/insulin_math.dart';
import '../analytics/therapy_settings.dart';
import '../core/samples.dart';

/// One historical day's data, as fed to [TimeOfDaySensitivityAnalyzer.learn].
///
/// [basal] and [boluses] may (and for accurate IOB at the start of the day,
/// *should*) extend up to one DIA before [day]'s midnight; only CGM steps inside
/// the day itself are scored.
class DayHistory {
  const DayHistory({
    required this.day,
    required this.cgm,
    required this.boluses,
    required this.basal,
    required this.carbs,
  });

  final DateTime day;
  final List<CgmSample> cgm;
  final List<BolusEvent> boluses;
  final List<BasalSegment> basal;
  final List<CarbEntry> carbs;
}

/// One day's sensitivity-multiplier sample for one time-of-day bucket.
class BucketObservation {
  const BucketObservation({
    required this.bucketIndex,
    required this.multiplier,
    required this.carbFreeMinutes,
  });

  final int bucketIndex;

  /// >1 = insulin underperformed settings in this bucket (resistant);
  /// <1 = overperformed (sensitive). Same convention as `DayResult`.
  final double multiplier;

  /// Carb-free, insulin-active observation minutes backing this sample.
  final int carbFreeMinutes;
}

/// Learns a [TimeOfDayProfile] from ≥[minDays] days of CGM + insulin history.
class TimeOfDaySensitivityAnalyzer {
  TimeOfDaySensitivityAnalyzer({
    InsulinModel? insulinModel,
    this.bucketCount = 8,
    this.minDays = 14,
    this.minBucketObservationMinutes = 1200, // 20 h total across days
    this.minDailyBucketMinutes = 30,
    this.minModelledEffectMgdl = 5.0,
    this.stepMinutes = 5,
  })  : assert(bucketCount > 0 && 1440 % bucketCount == 0,
            'bucketCount must divide 24 h evenly'),
        _model = insulinModel ?? InsulinModel.rapidActing;

  final InsulinModel _model;

  /// Buckets per day (default 8 → 3-hour buckets).
  final int bucketCount;

  /// Below this many days of history the profile stays neutral.
  final int minDays;

  /// A bucket needs at least this much *total* carb-free observation time across
  /// all days, else it stays neutral (default 20 h).
  final int minBucketObservationMinutes;

  /// A single day contributes a sample to a bucket only if it observed the bucket
  /// carb-free for at least this long.
  final int minDailyBucketMinutes;

  /// A day's bucket sample also needs at least this much total modelled insulin
  /// effect (mg/dL), so near-zero-IOB stretches can't produce ratio noise.
  final double minModelledEffectMgdl;

  /// Carb-window guard granularity; matches `Autotune.stepMinutes`.
  final int stepMinutes;

  int get bucketMinutes => 1440 ~/ bucketCount;

  /// Per-bucket multiplier samples for one day. Mirrors `Autotune.analyseDay`, but
  /// the observed-vs-modelled sums are kept per time-of-day bucket. Only buckets
  /// that cleared the per-day observation and modelled-effect floors are returned.
  List<BucketObservation> analyseDay({
    required DateTime day,
    required List<CgmSample> cgm,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required List<CarbEntry> carbs,
    required TherapySettings settings,
  }) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final sorted = [...cgm]
      ..removeWhere((s) => s.sensorWarmup || s.isCalibration || s.mgdl <= 0)
      ..sort((a, b) => a.time.compareTo(b.time));

    final iob = IobCalculator(model: _model);

    final observed = List.filled(bucketCount, 0.0);
    final modelled = List.filled(bucketCount, 0.0);
    final minutes = List.filled(bucketCount, 0);

    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final cur = sorted[i];
      if (cur.time.isBefore(dayStart) || !cur.time.isBefore(dayEnd)) continue;
      final gapMin = cur.time.difference(prev.time).inMinutes;
      if (gapMin <= 0 || gapMin > 15) continue; // skip gaps

      // Only use windows with no active carb absorption.
      final carbActive = carbs.any((c) {
        final since = cur.time.difference(c.time).inMinutes;
        return since >= -stepMinutes && since <= c.absorptionMinutes;
      });
      if (carbActive) continue;

      final seg = settings.segmentAt(cur.time);
      final act = iob.total(boluses, basal, cur.time).activityUnitsPerMin;
      final modelledDelta = -act * seg.isf * gapMin; // negative = drop
      final observedDelta = cur.mgdl - prev.mgdl;

      // Only attribute when insulin is meaningfully active (avoid divide noise).
      if (modelledDelta.abs() < 0.5) continue;

      final minuteOfDay = cur.time.hour * 60 + cur.time.minute;
      final bucket = math.min(minuteOfDay ~/ bucketMinutes, bucketCount - 1);
      observed[bucket] += observedDelta;
      modelled[bucket] += modelledDelta;
      minutes[bucket] += gapMin;
    }

    final samples = <BucketObservation>[];
    for (var b = 0; b < bucketCount; b++) {
      if (minutes[b] < minDailyBucketMinutes) continue;
      if (modelled[b].abs() < minModelledEffectMgdl) continue;
      // Observed drop smaller than modelled → insulin underperformed → resistant
      // (multiplier > 1); same damped conversion as Autotune.
      final ratio = observed[b] / modelled[b];
      final mult = (2 - ratio).clamp(0.6, 1.5).toDouble();
      samples.add(BucketObservation(
        bucketIndex: b,
        multiplier: mult,
        carbFreeMinutes: minutes[b],
      ));
    }
    return samples;
  }

  /// Aggregate per-day bucket samples into a profile with robust statistics.
  TimeOfDayProfile learn({
    required List<DayHistory> days,
    required TherapySettings settings,
  }) {
    if (days.length < minDays) {
      return TimeOfDayProfile.neutral(bucketCount: bucketCount);
    }

    final perBucket = List.generate(bucketCount, (_) => <double>[]);
    final observationMinutes = List.filled(bucketCount, 0);

    for (final d in days) {
      final samples = analyseDay(
        day: d.day,
        cgm: d.cgm,
        boluses: d.boluses,
        basal: d.basal,
        carbs: d.carbs,
        settings: settings,
      );
      for (final s in samples) {
        perBucket[s.bucketIndex].add(s.multiplier);
        observationMinutes[s.bucketIndex] += s.carbFreeMinutes;
      }
    }

    final multipliers = List.filled(bucketCount, 1.0);
    final confidences = List.filled(bucketCount, 0.0);
    for (var b = 0; b < bucketCount; b++) {
      final samples = perBucket[b]..sort();
      if (samples.isEmpty ||
          observationMinutes[b] < minBucketObservationMinutes) {
        continue; // stays neutral, zero confidence
      }
      multipliers[b] = _percentile(samples, 0.5).clamp(0.6, 1.5).toDouble();

      // Confidence: enough observation time × days agree with each other × enough
      // distinct days. Capped at 0.9 — this is never a certainty.
      final iqr = _percentile(samples, 0.75) - _percentile(samples, 0.25);
      final coverage = (observationMinutes[b] / minBucketObservationMinutes)
          .clamp(0.0, 1.0);
      final agreement = (1 - iqr / 0.4).clamp(0.0, 1.0);
      final volume = (samples.length / minDays).clamp(0.0, 1.0);
      confidences[b] = 0.9 * coverage * agreement * volume;
    }

    return TimeOfDayProfile(
      multipliers: multipliers,
      confidences: confidences,
      observationMinutes: observationMinutes,
      trainedDays: days.length,
    );
  }

  /// Linear-interpolated percentile of an already-sorted, non-empty list.
  static double _percentile(List<double> sorted, double p) {
    if (sorted.length == 1) return sorted.first;
    final rank = p * (sorted.length - 1);
    final lo = rank.floor();
    final hi = rank.ceil();
    if (lo == hi) return sorted[lo];
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (rank - lo);
  }
}

/// A learned time-of-day sensitivity profile: one multiplier + confidence per
/// bucket, with smooth circular interpolation between bucket midpoints.
class TimeOfDayProfile {
  TimeOfDayProfile({
    required List<double> multipliers,
    required List<double> confidences,
    List<int>? observationMinutes,
    this.trainedDays = 0,
  })  : assert(multipliers.isNotEmpty),
        assert(multipliers.length == confidences.length),
        assert(1440 % multipliers.length == 0),
        assert(observationMinutes == null ||
            observationMinutes.length == multipliers.length),
        _multipliers = List.unmodifiable(multipliers),
        _confidences = List.unmodifiable(confidences),
        _observationMinutes = List.unmodifiable(
            observationMinutes ?? List.filled(multipliers.length, 0));

  /// A flat profile: ×1.0 everywhere, zero confidence.
  factory TimeOfDayProfile.neutral({int bucketCount = 8}) => TimeOfDayProfile(
        multipliers: List.filled(bucketCount, 1.0),
        confidences: List.filled(bucketCount, 0.0),
      );

  final List<double> _multipliers;
  final List<double> _confidences;
  final List<int> _observationMinutes;

  /// Number of history days the profile was learned from (0 for neutral).
  final int trainedDays;

  int get bucketCount => _multipliers.length;
  int get bucketMinutes => 1440 ~/ bucketCount;

  /// True when nothing was learned — every bucket flat and untrusted.
  bool get isNeutral =>
      _multipliers.every((m) => m == 1.0) && _confidences.every((c) => c == 0.0);

  /// Per-bucket values for the advanced UI (bar chart / table).
  List<({int startMinute, double multiplier, double confidence})> get buckets =>
      [
        for (var b = 0; b < bucketCount; b++)
          (
            startMinute: b * bucketMinutes,
            multiplier: _multipliers[b],
            confidence: _confidences[b],
          ),
      ];

  /// Total carb-free observation minutes behind each bucket (advanced UI).
  List<int> get observationMinutes => _observationMinutes;

  /// Resistance multiplier at [time]'s local time-of-day, interpolated linearly
  /// between the two nearest bucket midpoints (wrapping across midnight).
  double multiplierAt(DateTime time) => _interpolate(_multipliers, time);

  /// Confidence at [time], interpolated the same way as [multiplierAt].
  double confidenceAt(DateTime time) => _interpolate(_confidences, time);

  double _interpolate(List<double> values, DateTime time) {
    final minute =
        time.hour * 60 + time.minute + time.second / 60.0; // fractional
    // Position in "midpoint units": midpoint of bucket k sits at k*bw + bw/2.
    final bw = bucketMinutes.toDouble();
    final pos = (minute - bw / 2) / bw;
    final i0 = pos.floor();
    final frac = pos - i0;
    final a = values[(i0 % bucketCount + bucketCount) % bucketCount];
    final b = values[((i0 + 1) % bucketCount + bucketCount) % bucketCount];
    return a + (b - a) * frac;
  }

  /// Combine the time-of-day adjustment with the model's daily context into one
  /// [SensitivityContext] for the advisor/predictor at [time].
  ///
  /// Multipliers multiply (both effects apply); confidence is the *minimum* of the
  /// two when both sides carry a signal — the combined adjustment is only as
  /// trustworthy as its weakest part. A neutral side (×1.0, zero confidence) is
  /// simply "no adjustment", so it must not drag the other side's confidence to
  /// zero; the non-neutral side's confidence is used instead.
  SensitivityContext contextAt(
    DateTime time, {
    SensitivityContext daily = SensitivityContext.neutral,
  }) {
    final todMult = multiplierAt(time);
    final todConf = confidenceAt(time);

    final combined =
        (daily.resistanceMultiplier * todMult).clamp(0.5, 1.6).toDouble();

    final dailyNeutral = daily.confidence <= 0;
    final todNeutral = todConf <= 0;
    final double confidence;
    if (dailyNeutral && todNeutral) {
      confidence = 0.0;
    } else if (dailyNeutral) {
      confidence = todConf;
    } else if (todNeutral) {
      confidence = daily.confidence;
    } else {
      confidence = math.min(daily.confidence, todConf);
    }

    final reasons = <String>{
      ...daily.reasons,
      ..._timeOfDayReasons(time, todMult, todConf),
    }.toList();

    return SensitivityContext(
      resistanceMultiplier: combined,
      confidence: confidence,
      reasons: reasons,
    );
  }

  List<String> _timeOfDayReasons(DateTime time, double mult, double conf) {
    if (conf <= 0) return const [];
    final minute = time.hour * 60 + time.minute;
    if (mult > 1.1) {
      if (minute >= 3 * 60 && minute < 9 * 60) return const ['dawn effect'];
      if (minute >= 18 * 60) return const ['evening resistance'];
      return const ['time-of-day resistance'];
    }
    if (mult < 0.9) return const ['time-of-day sensitivity'];
    return const [];
  }

  Map<String, dynamic> toJson() => {
        'trainedDays': trainedDays,
        'buckets': [
          for (var b = 0; b < bucketCount; b++)
            {
              'startMinute': b * bucketMinutes,
              'multiplier': _multipliers[b],
              'confidence': _confidences[b],
              'observationMinutes': _observationMinutes[b],
            },
        ],
      };

  factory TimeOfDayProfile.fromJson(Map<String, dynamic> json) {
    final raw = (json['buckets'] as List)
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) =>
          (a['startMinute'] as num).compareTo(b['startMinute'] as num));
    return TimeOfDayProfile(
      multipliers: [for (final b in raw) (b['multiplier'] as num).toDouble()],
      confidences: [for (final b in raw) (b['confidence'] as num).toDouble()],
      observationMinutes: [
        for (final b in raw) (b['observationMinutes'] as num?)?.toInt() ?? 0
      ],
      trainedDays: (json['trainedDays'] as num?)?.toInt() ?? 0,
    );
  }
}
