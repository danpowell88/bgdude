/// A1c / GMI goal tracking + short-horizon projection.
///
/// GMI (Glucose Management Indicator) is the CGM-derived estimate of lab A1c:
///   GMI% = 3.31 + 0.02392 × mean glucose (mg/dL)
/// (Bergenstal et al., Diabetes Care 2018). We report where you are now against
/// a personal goal, and project ~2 weeks out by fitting a linear trend to your
/// recent daily-mean glucose. This is a motivational estimate, not a lab result.
library;

import '../analytics/metrics.dart';

/// A snapshot of GMI vs goal, with an optional forward projection.
class GmiStatus {
  /// GMI% implied by the recent window's mean glucose.
  final double currentGmiPercent;

  /// GMI% projected ~14 days out from the daily-mean trend; null when there
  /// aren't enough days (< 5) to fit a trend.
  final double? projectedGmiPercent;

  final double targetGmiPercent;

  /// True when already at/under target, or when the projection is trending
  /// toward (and reaching) target.
  final bool onTrack;

  /// currentGmiPercent − targetGmiPercent. Positive = above goal.
  final double deltaToTargetPercent;

  const GmiStatus({
    required this.currentGmiPercent,
    required this.projectedGmiPercent,
    required this.targetGmiPercent,
    required this.onTrack,
    required this.deltaToTargetPercent,
  });

  /// One-line human summary, e.g.
  /// "GMI 7.1% — 0.4% above your 6.7% goal; trending down."
  String get summary {
    final cur = currentGmiPercent.toStringAsFixed(1);
    final tgt = targetGmiPercent.toStringAsFixed(1);
    final mag = deltaToTargetPercent.abs().toStringAsFixed(1);

    final String relation;
    if (deltaToTargetPercent > 0.05) {
      relation = '$mag% above your $tgt% goal';
    } else if (deltaToTargetPercent < -0.05) {
      relation = '$mag% below your $tgt% goal';
    } else {
      relation = 'right on your $tgt% goal';
    }

    final String? trend;
    if (projectedGmiPercent == null) {
      trend = null;
    } else {
      final diff = projectedGmiPercent! - currentGmiPercent;
      if (diff < -0.05) {
        trend = 'trending down';
      } else if (diff > 0.05) {
        trend = 'trending up';
      } else {
        trend = 'holding steady';
      }
    }

    return trend == null
        ? 'GMI $cur% — $relation.'
        : 'GMI $cur% — $relation; $trend.';
  }
}

class A1cTracker {
  const A1cTracker();

  /// Days of history required to fit a trend and project forward.
  static const int _minDaysForProjection = 5;

  /// How far forward (days) to extrapolate the daily-mean trend.
  static const int _projectionHorizonDays = 14;

  GmiStatus status({
    required GlucoseMetrics recent,
    required List<double> dailyMeanMgdlHistory,
    required double targetGmiPercent,
  }) {
    final currentGmi = recent.gmi;
    final delta = currentGmi - targetGmiPercent;

    final projectedGmi = _project(dailyMeanMgdlHistory);

    // On track if we're already at/under goal, or the projection reaches it.
    final onTrack = currentGmi <= targetGmiPercent ||
        (projectedGmi != null && projectedGmi <= targetGmiPercent);

    return GmiStatus(
      currentGmiPercent: currentGmi,
      projectedGmiPercent: projectedGmi,
      targetGmiPercent: targetGmiPercent,
      onTrack: onTrack,
      deltaToTargetPercent: delta,
    );
  }

  /// Fit y = a + b·x to (day index, daily mean) via ordinary least squares,
  /// extrapolate [_projectionHorizonDays] past the last day, and convert the
  /// projected mean to GMI. Null when < [_minDaysForProjection] days.
  static double? _project(List<double> dailyMeanMgdlHistory) {
    final n = dailyMeanMgdlHistory.length;
    if (n < _minDaysForProjection) return null;

    var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0;
    for (var i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = dailyMeanMgdlHistory[i];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }
    final denom = n * sumXX - sumX * sumX;
    final meanY = sumY / n;
    final double projectedMean;
    if (denom == 0) {
      // Degenerate x (shouldn't happen for distinct indices) → flat.
      projectedMean = meanY;
    } else {
      final slope = (n * sumXY - sumX * sumY) / denom;
      final intercept = (sumY - slope * sumX) / n;
      final futureX = (n - 1) + _projectionHorizonDays.toDouble();
      projectedMean = intercept + slope * futureX;
    }

    // GMI = 3.31 + 0.02392 × mean glucose (mg/dL). Clamp to a sane floor so a
    // steep short-term slope can't project a physically impossible mean.
    final clampedMean = projectedMean < 0 ? 0.0 : projectedMean;
    return 3.31 + 0.02392 * clampedMean;
  }
}
