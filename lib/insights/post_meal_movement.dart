/// Post-meal movement help, from the evidence that even a short walk after eating blunts
/// the glucose spike. Two pieces:
///   * [PostMealMovementCoach] — a real-time "a short walk now would help" decision, when
///     a spike is predicted soon after a meal and you're not already moving.
///   * [PostMealMovementAnalyzer] — your own correlation between post-meal steps and the
///     size of the spike, for the Meals report.
library;

import 'dart:math' as math;

import '../data/health_sync.dart';

class PostMealMovementCoach {
  const PostMealMovementCoach({
    this.peakThresholdMgdl = 160,
    this.minRiseMgdl = 25,
    this.activeStepsPerMin = 40,
  });

  /// Only nudge if the forecast peak is at least this high…
  final double peakThresholdMgdl;

  /// …and rising at least this much above current.
  final double minRiseMgdl;

  /// If recent cadence is already above this, you're moving — don't nudge.
  final double activeStepsPerMin;

  /// Whether to suggest a short walk now.
  bool shouldNudge({
    required bool ateWithinWindow,
    required double currentMgdl,
    required double forecastPeakMgdl,
    required double recentStepsPerMin,
  }) {
    if (!ateWithinWindow) return false;
    if (recentStepsPerMin >= activeStepsPerMin) return false;
    if (forecastPeakMgdl < peakThresholdMgdl) return false;
    return (forecastPeakMgdl - currentMgdl) >= minRiseMgdl;
  }
}

class PostMealMovementResult {
  const PostMealMovementResult({
    required this.meals,
    required this.r,
    required this.hasSignal,
    required this.message,
  });
  final int meals;
  final double r;
  final bool hasSignal;
  final String message;

  static const PostMealMovementResult none = PostMealMovementResult(
      meals: 0, r: 0, hasSignal: false, message: '');
}

class PostMealMovementAnalyzer {
  const PostMealMovementAnalyzer({
    this.minMeals = 6,
    this.minAbsR = 0.25,
    this.window = const Duration(hours: 2),
  });

  final int minMeals;
  final double minAbsR;
  final Duration window;

  /// Correlate post-meal steps (summed over [window]) against each meal's excursion.
  PostMealMovementResult analyze({
    required List<({DateTime eatenAt, double excursionMgdl})> meals,
    required List<HealthSample> steps,
  }) {
    final xs = <double>[]; // steps after the meal
    final ys = <double>[]; // excursion
    for (final m in meals) {
      final end = m.eatenAt.add(window);
      var s = 0.0;
      for (final st in steps) {
        if (st.type != HealthMetric.steps) continue;
        if (!st.time.isBefore(m.eatenAt) && st.time.isBefore(end)) s += st.value;
      }
      xs.add(s);
      ys.add(m.excursionMgdl);
    }
    if (xs.length < minMeals) return PostMealMovementResult.none;
    final r = _pearson(xs, ys);
    if (r.isNaN || r.abs() < minAbsR) {
      return PostMealMovementResult(
          meals: xs.length, r: r.isNaN ? 0 : r, hasSignal: false, message: '');
    }
    final msg = r < 0
        ? 'More movement after meals was associated with smaller spikes '
            '(r ${r.toStringAsFixed(2)}, ${xs.length} meals). A short walk helps.'
        : 'Post-meal movement did not track smaller spikes for you '
            '(r ${r.toStringAsFixed(2)}, ${xs.length} meals).';
    return PostMealMovementResult(
        meals: xs.length, r: r, hasSignal: true, message: msg);
  }

  static double _pearson(List<double> xs, List<double> ys) {
    final n = xs.length;
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    var num = 0.0, dx = 0.0, dy = 0.0;
    for (var i = 0; i < n; i++) {
      final a = xs[i] - mx, b = ys[i] - my;
      num += a * b;
      dx += a * a;
      dy += b * b;
    }
    final den = math.sqrt(dx * dy);
    return den == 0 ? double.nan : num / den;
  }
}
