/// What a trainer actually saw and used (TASK-140), so a user (or a developer
/// debugging a report of "the model won't train") can see WHY a model declined to
/// train or a bucket/horizon stayed low-confidence, instead of the counts being
/// computed internally and then silently discarded. Shared across the sensitivity/
/// time-of-day trainer (`sensitivity_training.dart`) and the forecaster trainer
/// (`forecaster_training.dart`) — each populates only the fields it produces.
library;

class TrainingCensus {
  const TrainingCensus({
    this.totalDays = 0,
    this.usableDays = 0,
    this.perBucketMinutes = const {},
    this.perHorizonSamples = const {},
    this.healthFeatureCoverage,
  });

  /// Days of history considered.
  final int totalDays;

  /// Of [totalDays], how many actually qualified for training (passed the
  /// trainer's own usability gate — e.g. enough carb-free time, enough CGM).
  final int usableDays;

  /// Time-of-day only: bucket start-minute → total carb-free observation
  /// minutes accumulated for that bucket across all usable days. Empty for
  /// trainers that don't bucket by time of day.
  final Map<int, int> perBucketMinutes;

  /// Forecaster only: horizon minutes → training-sample count after cleaning.
  /// Empty for trainers that aren't per-horizon.
  final Map<int, int> perHorizonSamples;

  /// Forecaster only: fraction of training rows whose health features (steps/
  /// exercise/heart rate) were non-zero. Null when the trainer doesn't consume
  /// health data at all (sensitivity/time-of-day).
  final double? healthFeatureCoverage;
}
