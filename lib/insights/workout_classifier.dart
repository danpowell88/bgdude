/// Classifies a workout's activity type into the categories that matter for glucose:
/// aerobic exercise tends to drop glucose and raise *nocturnal* hypo risk, while
/// resistance/anaerobic work has a smaller acute drop. Used to tailor post-exercise
/// low warnings (per the T1D exercise literature).
library;

enum WorkoutType { aerobic, resistance, mixed, other }

extension WorkoutTypeX on WorkoutType {
  /// Aerobic and mixed sessions carry the higher post-exercise / nocturnal hypo risk.
  bool get raisesHypoRisk =>
      this == WorkoutType.aerobic || this == WorkoutType.mixed;
}

class WorkoutClassifier {
  const WorkoutClassifier();

  /// Classify from a Health Connect / Garmin activity string (e.g. "RUNNING",
  /// "STRENGTH_TRAINING", "HIGH_INTENSITY_INTERVAL_TRAINING").
  WorkoutType classify(String activity) {
    final a = activity.toLowerCase();
    if (_any(a, const ['strength', 'weight', 'resistance', 'lifting'])) {
      return WorkoutType.resistance;
    }
    if (_any(a, const ['crossfit', 'hiit', 'interval', 'circuit', 'boot'])) {
      return WorkoutType.mixed;
    }
    if (_any(a, const [
      'run', 'jog', 'walk', 'hik', 'cycl', 'bik', 'spin', 'swim', 'row',
      'elliptical', 'cardio', 'aerobic', 'danc'
    ])) {
      return WorkoutType.aerobic;
    }
    return WorkoutType.other;
  }

  static bool _any(String s, List<String> keys) => keys.any(s.contains);
}
