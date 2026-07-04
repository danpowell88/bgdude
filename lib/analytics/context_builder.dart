/// Builds the sensitivity model's [ContextFeatures] from Health Connect samples.
///
/// "Today" values are the most recent readings (last night's sleep, overnight HRV,
/// morning resting HR, yesterday's exercise load); baselines are robust medians over a
/// longer window so the model reasons about *relative* change (HRV vs your baseline)
/// rather than absolute numbers, which vary hugely between people.
library;

import '../data/health_sync.dart';
import '../ml/sensitivity_model.dart';

class ContextBuilder {
  const ContextBuilder._();

  /// Returns null when there isn't enough health data to say anything useful.
  static ContextFeatures? build({
    required List<HealthSample> today,
    required List<HealthSample> baseline,
    double menstrualLutealPhase = 0,
    double illnessFlag = 0,
  }) {
    if (today.isEmpty && baseline.isEmpty) return null;

    double? latest(List<HealthSample> src, String type) {
      final matching = [for (final s in src) if (s.type == type) s]
        ..sort((a, b) => a.time.compareTo(b.time));
      return matching.isEmpty ? null : matching.last.value;
    }

    double median(List<HealthSample> src, String type) {
      final vals = [for (final s in src) if (s.type == type) s.value]..sort();
      if (vals.isEmpty) return 0;
      final n = vals.length;
      return n.isOdd
          ? vals[n ~/ 2]
          : (vals[n ~/ 2 - 1] + vals[n ~/ 2]) / 2;
    }

    final sleepHours = latest(today, 'sleepHours') ?? 7.5;
    final sleepEfficiency = latest(today, 'sleepEfficiency') ?? 0.9;
    final hrv = latest(today, 'hrvRmssd') ?? median(baseline, 'hrvRmssd');
    final restingHr = latest(today, 'restingHr') ?? median(baseline, 'restingHr');

    // Yesterday's exercise load: total workout minutes in the last 36h, normalised
    // (~90 min of activity → full load).
    var exerciseMinutes = 0.0;
    for (final s in today) {
      if (s.type == 'exercise') exerciseMinutes += s.value;
    }
    final exerciseLoad = (exerciseMinutes / 90.0).clamp(0.0, 1.0);

    final baselineHrv = median(baseline, 'hrvRmssd');
    final baselineRestingHr = median(baseline, 'restingHr');

    return ContextFeatures(
      sleepHours: sleepHours,
      sleepEfficiency: sleepEfficiency,
      overnightHrvRmssd: hrv,
      restingHr: restingHr,
      priorDayExerciseLoad: exerciseLoad,
      menstrualLutealPhase: menstrualLutealPhase,
      illnessFlag: illnessFlag,
      baselineHrv: baselineHrv,
      baselineRestingHr: baselineRestingHr,
    );
  }
}
