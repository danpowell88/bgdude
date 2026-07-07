/// Acute activity features for the BG forecaster, derived from Google Fit / Health
/// Connect data (steps + workouts + heart rate). These are *near-term-BG-relevant*
/// signals — recent movement, post-exercise sensitivity, and heart-rate elevation
/// (exercise/stress) — and are deliberately distinct from the slower daily sensitivity
/// context (`sensitivity_model.dart`).
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
    this.hrWindow = const Duration(minutes: 15),
  })  : _steps = (samples.where((s) => s.type == HealthMetric.steps).toList()
          ..sort((a, b) => a.time.compareTo(b.time))),
        _exercise = (samples.where((s) => s.type == HealthMetric.exercise).toList()
          ..sort((a, b) => a.time.compareTo(b.time))),
        _hr = (samples.where((s) => s.type == HealthMetric.heartRate).toList()
          ..sort((a, b) => a.time.compareTo(b.time))),
        _restingHr = (samples.where((s) => s.type == HealthMetric.restingHr).toList()
          ..sort((a, b) => a.time.compareTo(b.time)));

  /// Steps are summed over this trailing window to estimate current movement.
  final Duration stepsWindow;

  /// A workout's sensitivity boost is considered over this trailing window.
  final Duration exerciseWindow;

  /// Post-exercise effect decays with this half-life after the workout ends.
  final Duration exerciseHalfLife;

  /// Steps/min treated as "fully active" (a brisk walk), i.e. activity feature = 1.0.
  final double briskStepsPerMin;

  /// A heart-rate reading counts as "current" if within this window of the timestamp.
  final Duration hrWindow;

  final List<HealthSample> _steps;
  final List<HealthSample> _exercise;
  final List<HealthSample> _hr;

  /// Resting-HR readings (time-sorted). The baseline is computed *trailing* at query
  /// time (readings at or before t) so a historical feature never sees a future reading
  /// (P2-7 look-ahead-leak fix).
  final List<HealthSample> _restingHr;

  /// Median resting HR over readings at or before [t] (0 when none yet → no HR signal).
  double _restingBaselineAt(DateTime t) {
    final upto = _upperBound(_restingHr, t); // first index strictly after t
    if (upto == 0) return 0;
    return _median(_restingHr.take(upto).map((s) => s.value));
  }

  /// Index of the first sample whose time is strictly after [t] (binary search; the
  /// lists are time-sorted). `[_lowerBoundExclusive(from), _upperBound(t))` is the
  /// half-open trailing window `(from, t]`.
  static int _upperBound(List<HealthSample> list, DateTime t) {
    var lo = 0;
    var hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid].time.isAfter(t)) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  /// Number of features this sampler contributes to the forecast vector.
  static const int featureCount = 3;

  static const List<String> names = ['activity', 'exercise_recency', 'hr_rel'];

  /// The all-zero feature contribution (no activity data). Used as the default so the
  /// forecast vector keeps a constant length whether or not health data is present.
  static const List<double> zeros = [0.0, 0.0, 0.0];

  /// Features at [t]: `[activity, exerciseRecency, hrRel]`.
  List<double> featuresAt(DateTime t) =>
      [_activityAt(t), _exerciseRecencyAt(t), _hrRelAt(t)];

  /// Heart rate relative to the resting baseline at [t]: (hr − resting)/resting, clamped.
  /// 0 when there's no baseline or no recent reading.
  ///
  /// TASK-132: BACKWARD-ONLY — the nearest reading at or before [t] within
  /// [hrWindow]. The old bidirectional ±window let historical training rows read
  /// a FUTURE heart-rate sample (train/serve skew: live serving only has the
  /// past), inflating offline accuracy.
  double _hrRelAt(DateTime t) {
    final baseline = _restingBaselineAt(t);
    if (baseline <= 0 || _hr.isEmpty) return 0;
    HealthSample? nearest;
    var bestGap = hrWindow;
    for (final s in _hr) {
      if (s.time.isAfter(t)) continue; // never read the future
      final gap = t.difference(s.time);
      if (gap <= bestGap) {
        bestGap = gap;
        nearest = s;
      }
    }
    if (nearest == null) return 0;
    return ((nearest.value - baseline) / baseline)
        .clamp(-0.5, 1.0)
        .toDouble();
  }

  static double _median(Iterable<double> values) {
    final v = values.toList()..sort();
    if (v.isEmpty) return 0;
    final mid = v.length ~/ 2;
    return v.length.isOdd ? v[mid] : (v[mid - 1] + v[mid]) / 2;
  }

  /// Trailing-window step rate, normalised to [0, 1.5] against a brisk-walk cadence.
  double _activityAt(DateTime t) {
    final from = t.subtract(stepsWindow);
    // Binary-search the trailing window (from, t] instead of scanning the whole list.
    final lo = _upperBound(_steps, from); // first strictly after `from`
    final hi = _upperBound(_steps, t); // first strictly after `t`
    var steps = 0.0;
    for (var i = lo; i < hi; i++) {
      steps += _steps[i].value;
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
