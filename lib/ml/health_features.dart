/// Acute activity features for the BG forecaster, derived from Google Fit / Health
/// Connect data (steps + workouts). These are *near-term-BG-relevant* signals — recent
/// movement and post-exercise insulin sensitivity — and are deliberately distinct from
/// the slower daily sensitivity context (`sensitivity_model.dart`).
///
/// The sampler is built once from a window of [HealthSample]s and can then be queried at
/// any timestamp, so the exact same feature is produced at training time (over historical
/// timesteps) and at inference (from recent samples). When no activity data covers a
/// timestamp the features are simply 0 — the forecaster learns to ignore them, so older
/// history without wearables trains cleanly alongside newer data.
library;

import 'dart:math' as math;

import '../data/health_sync.dart';

class HealthFeatureSampler {
  HealthFeatureSampler(
    List<HealthSample> samples, {
    this.stepsWindow = const Duration(minutes: 30),
    this.exerciseWindow = const Duration(hours: 3),
    this.exerciseHalfLife = const Duration(minutes: 90),
    this.briskStepsPerMin = 100.0,
  })  : _steps = (samples.where((s) => s.type == 'steps').toList()
          ..sort((a, b) => a.time.compareTo(b.time))),
        _exercise = (samples.where((s) => s.type == 'exercise').toList()
          ..sort((a, b) => a.time.compareTo(b.time)));

  /// Steps are summed over this trailing window to estimate current movement.
  final Duration stepsWindow;

  /// A workout's sensitivity boost is considered over this trailing window.
  final Duration exerciseWindow;

  /// Post-exercise effect decays with this half-life after the workout ends.
  final Duration exerciseHalfLife;

  /// Steps/min treated as "fully active" (a brisk walk), i.e. activity feature = 1.0.
  final double briskStepsPerMin;

  final List<HealthSample> _steps;
  final List<HealthSample> _exercise;

  /// Number of features this sampler contributes to the forecast vector.
  static const int featureCount = 2;

  static const List<String> names = ['activity', 'exercise_recency'];

  /// The all-zero feature contribution (no activity data). Used as the default so the
  /// forecast vector keeps a constant length whether or not health data is present.
  static const List<double> zeros = [0.0, 0.0];

  /// Features at [t]: `[activity, exerciseRecency]`.
  List<double> featuresAt(DateTime t) => [_activityAt(t), _exerciseRecencyAt(t)];

  /// Trailing-window step rate, normalised to [0, 1.5] against a brisk-walk cadence.
  double _activityAt(DateTime t) {
    final from = t.subtract(stepsWindow);
    var steps = 0.0;
    for (final s in _steps) {
      if (s.time.isAfter(t)) break; // sorted; nothing later can count
      if (s.time.isAfter(from)) steps += s.value;
    }
    final perMin = steps / stepsWindow.inMinutes;
    return (perMin / briskStepsPerMin).clamp(0.0, 1.5).toDouble();
  }

  /// 1.0 during/just after a workout, decaying to 0 over [exerciseWindow]. Max across
  /// overlapping workouts.
  double _exerciseRecencyAt(DateTime t) {
    var best = 0.0;
    final halfLifeMin = exerciseHalfLife.inMinutes;
    for (final e in _exercise) {
      final start = e.time;
      if (start.isAfter(t)) break; // sorted; workout hasn't started yet
      final end = start.add(Duration(minutes: e.value.round()));
      double v;
      if (!t.isBefore(start) && t.isBefore(end)) {
        v = 1.0; // mid-workout
      } else {
        final sinceEnd = t.difference(end);
        if (sinceEnd.isNegative || sinceEnd > exerciseWindow) continue;
        v = math.pow(0.5, sinceEnd.inMinutes / halfLifeMin).toDouble();
      }
      if (v > best) best = v;
    }
    return best;
  }
}
