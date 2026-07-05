/// Standard CGM glycaemic metrics: Time in Range, GMI, CV, and the AGP percentile
/// bands. Formulas follow the International Consensus on Time in Range
/// (Diabetes Care 2019; https://diabetesjournals.org/care/article/42/8/1593).
///
/// Metrics gate on data sufficiency: TIR/GMI need ≥14 days and ≥70% CGM active time
/// to be considered valid. The engine still computes them below that but flags
/// `sufficient == false` so the UI can caveat.
library;

import 'dart:math' as math;

import '../core/samples.dart';
import '../core/units.dart';

class GlucoseMetrics {
  const GlucoseMetrics({
    required this.readingCount,
    required this.meanMgdl,
    required this.sdMgdl,
    required this.timeInRange,
    required this.timeInTightRange,
    required this.timeBelow70,
    required this.timeBelow54,
    required this.timeAbove180,
    required this.timeAbove250,
    required this.coveragePeriod,
    required this.expectedReadings,
    required this.sufficient,
  });

  final int readingCount;
  final double meanMgdl;
  final double sdMgdl;

  /// Fractions in 0..1.
  final double timeInRange;

  /// Time in Tight Range (70–140 mg/dL) — a stricter companion to TIR.
  final double timeInTightRange;
  final double timeBelow70;
  final double timeBelow54;
  final double timeAbove180;
  final double timeAbove250;

  final Duration coveragePeriod;
  final int expectedReadings;

  /// True when ≥14 days and ≥70% active — the threshold for a valid AGP/GMI.
  final bool sufficient;

  /// Glucose Management Indicator (estimated A1c proxy), %.
  /// GMI = 3.31 + 0.02392 × mean glucose (mg/dL).
  double get gmi => 3.31 + 0.02392 * meanMgdl;

  /// Coefficient of variation, %. Stable ≤ 36%.
  double get cvPercent => meanMgdl == 0 ? 0 : (sdMgdl / meanMgdl) * 100;

  /// International-consensus threshold: CV ≥ 36% marks "labile" glucose and
  /// independently predicts serious (<54) hypoglycemia.
  bool get variabilityHigh => cvPercent >= 36;

  /// Fraction of expected readings actually present (CGM active time).
  double get activeFraction =>
      expectedReadings == 0 ? 0 : readingCount / expectedReadings;

  /// Mean glucose as a display value in the requested unit.
  String meanDisplay(GlucoseUnit unit) => Mgdl(meanMgdl).display(unit);
}

class MetricsCalculator {
  const MetricsCalculator({this.readingIntervalMinutes = 5});

  /// Nominal CGM cadence, used to compute expected reading count for active-time.
  final int readingIntervalMinutes;

  GlucoseMetrics compute(List<CgmSample> samples) {
    final valid = samples
        .where((s) => !s.sensorWarmup && s.mgdl > 0)
        .toList(growable: false);
    if (valid.isEmpty) {
      return const GlucoseMetrics(
        readingCount: 0,
        meanMgdl: 0,
        sdMgdl: 0,
        timeInRange: 0,
        timeInTightRange: 0,
        timeBelow70: 0,
        timeBelow54: 0,
        timeAbove180: 0,
        timeAbove250: 0,
        coveragePeriod: Duration.zero,
        expectedReadings: 0,
        sufficient: false,
      );
    }

    final sorted = [...valid]..sort((a, b) => a.time.compareTo(b.time));
    final period = sorted.last.time.difference(sorted.first.time);
    final expected = period.inMinutes ~/ readingIntervalMinutes + 1;

    var sum = 0.0;
    var inRange = 0, inTight = 0, below70 = 0, below54 = 0, above180 = 0, above250 = 0;
    for (final s in valid) {
      sum += s.mgdl;
      if (s.mgdl < GlucoseThresholds.veryLow) below54++;
      if (s.mgdl < GlucoseThresholds.low) below70++;
      if (s.mgdl >= GlucoseThresholds.low && s.mgdl <= GlucoseThresholds.high) {
        inRange++;
      }
      if (s.mgdl >= GlucoseThresholds.low && s.mgdl <= GlucoseThresholds.tightHigh) {
        inTight++;
      }
      if (s.mgdl > GlucoseThresholds.high) above180++;
      if (s.mgdl > GlucoseThresholds.veryHigh) above250++;
    }
    final n = valid.length;
    final mean = sum / n;
    var sqSum = 0.0;
    for (final s in valid) {
      final d = s.mgdl - mean;
      sqSum += d * d;
    }
    final sd = math.sqrt(sqSum / n);

    final activeFraction = expected == 0 ? 0.0 : n / expected;
    final enoughDays = period.inDays >= 14;
    final sufficient = enoughDays && activeFraction >= 0.70;

    return GlucoseMetrics(
      readingCount: n,
      meanMgdl: mean,
      sdMgdl: sd,
      timeInRange: inRange / n,
      timeInTightRange: inTight / n,
      timeBelow70: below70 / n,
      timeBelow54: below54 / n,
      timeAbove180: above180 / n,
      timeAbove250: above250 / n,
      coveragePeriod: period,
      expectedReadings: expected,
      sufficient: sufficient,
    );
  }
}

/// One point in an AGP (Ambulatory Glucose Profile) curve: percentile bands of
/// glucose across all days, bucketed by time-of-day.
class AgpBucket {
  const AgpBucket({
    required this.minuteOfDay,
    required this.p05,
    required this.p25,
    required this.median,
    required this.p75,
    required this.p95,
    required this.count,
  });

  final int minuteOfDay;
  final double p05;
  final double p25;
  final double median;
  final double p75;
  final double p95;
  final int count;
}

class AgpCalculator {
  const AgpCalculator({this.bucketMinutes = 60});

  /// Width of each time-of-day bucket (60 min gives a standard 24-point AGP;
  /// use 30 for a smoother curve).
  final int bucketMinutes;

  List<AgpBucket> compute(List<CgmSample> samples) {
    final buckets = <int, List<double>>{};
    for (final s in samples) {
      if (s.sensorWarmup || s.mgdl <= 0) continue;
      final minuteOfDay = s.time.hour * 60 + s.time.minute;
      final key = (minuteOfDay ~/ bucketMinutes) * bucketMinutes;
      (buckets[key] ??= <double>[]).add(s.mgdl);
    }
    final result = <AgpBucket>[];
    final keys = buckets.keys.toList()..sort();
    for (final k in keys) {
      final vals = buckets[k]!..sort();
      result.add(AgpBucket(
        minuteOfDay: k,
        p05: _percentile(vals, 0.05),
        p25: _percentile(vals, 0.25),
        median: _percentile(vals, 0.50),
        p75: _percentile(vals, 0.75),
        p95: _percentile(vals, 0.95),
        count: vals.length,
      ));
    }
    return result;
  }

  static double _percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted.first;
    final rank = p * (sorted.length - 1);
    final lo = rank.floor();
    final hi = rank.ceil();
    if (lo == hi) return sorted[lo];
    final frac = rank - lo;
    return sorted[lo] * (1 - frac) + sorted[hi] * frac;
  }
}
