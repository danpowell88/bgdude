/// Exercise announcement mode: the user tells the app about an upcoming or in-progress
/// workout so it can be *proactive* rather than reactive — raise the low-alert threshold
/// for the session (and its post-exercise tail), suggest a pre-exercise snack from the
/// live glucose/IOB picture, and arm the nocturnal-low watch.
///
/// Grounded in the T1D exercise literature: aerobic activity drops glucose during and for
/// hours after (bigger, longer effect); resistance/anaerobic has a smaller acute drop.
library;

import 'workout_classifier.dart';

class ExercisePlan {
  const ExercisePlan({
    required this.startAt,
    required this.durationMinutes,
    required this.type,
  });

  final DateTime startAt;
  final int durationMinutes;
  final WorkoutType type;

  DateTime get endAt => startAt.add(Duration(minutes: durationMinutes));

  /// Post-exercise sensitivity lingers — longer for aerobic sessions.
  Duration get tail =>
      type.raisesHypoRisk ? const Duration(hours: 8) : const Duration(hours: 3);

  DateTime get effectEnd => endAt.add(tail);

  /// Whether the raised low-alert threshold applies now: from 15 min before the start
  /// (pre-exercise) through the end plus the post-exercise tail.
  bool affectsAt(DateTime now) =>
      !now.isBefore(startAt.subtract(const Duration(minutes: 15))) &&
      now.isBefore(effectEnd);

  Map<String, dynamic> toJson() => {
        'startAt': startAt.toIso8601String(),
        'durationMinutes': durationMinutes,
        'type': type.name,
      };

  factory ExercisePlan.fromJson(Map<String, dynamic> j) => ExercisePlan(
        startAt: DateTime.parse(j['startAt'] as String),
        durationMinutes: (j['durationMinutes'] as num).toInt(),
        type: WorkoutType.values.asNameMap()[j['type']] ?? WorkoutType.aerobic,
      );
}

class ExercisePrep {
  const ExercisePrep({required this.suggestedCarbsGrams, required this.message});
  final double suggestedCarbsGrams;
  final String message;
}

class ExerciseModeCoach {
  const ExerciseModeCoach({
    this.aerobicLowBumpMgdl = 20,
    this.resistanceLowBumpMgdl = 8,
    this.snackThresholdMgdl = 126, // ~7.0 mmol/L
    this.lowStartMgdl = 90,
    this.highIobUnits = 1.5,
    this.fallingRocMgdlPerMin = -1.0,
    this.maxSnackGrams = 45,
  });

  final double aerobicLowBumpMgdl;
  final double resistanceLowBumpMgdl;
  final double snackThresholdMgdl;
  final double lowStartMgdl;
  final double highIobUnits;
  final double fallingRocMgdlPerMin;
  final double maxSnackGrams;

  /// How much to raise the low-alert threshold for a session of [type].
  double lowBump(WorkoutType type) =>
      type.raisesHypoRisk ? aerobicLowBumpMgdl : resistanceLowBumpMgdl;

  /// Pre-exercise snack advice from the live picture. Aerobic/mixed sessions are the ones
  /// that drop glucose, so resistance-only gets a lighter recommendation.
  ExercisePrep prep({
    required double currentMgdl,
    required double iobUnits,
    required double rocMgdlPerMin,
    required WorkoutType type,
  }) {
    if (!type.raisesHypoRisk) {
      return const ExercisePrep(
        suggestedCarbsGrams: 0,
        message: 'Resistance work has a smaller effect on glucose — keep fast carbs '
            'handy, but a pre-snack usually isn\'t needed.',
      );
    }
    var grams = 0.0;
    if (currentMgdl < lowStartMgdl) {
      grams += 30;
    } else if (currentMgdl < snackThresholdMgdl) {
      grams += 15;
    }
    if (iobUnits > highIobUnits) grams += 15;
    if (rocMgdlPerMin <= fallingRocMgdlPerMin) grams += 10;
    grams = (grams.clamp(0, maxSnackGrams) / 5).round() * 5;

    final message = grams > 0
        ? 'Have ~${grams.round()}g of carbs before you start — you\'re '
            '${currentMgdl < snackThresholdMgdl ? 'on the lower side' : 'carrying insulin/dropping'} '
            'and aerobic exercise will pull glucose down.'
        : 'Your BG looks OK to start. Keep fast carbs on you and re-check partway '
            'through.';
    return ExercisePrep(suggestedCarbsGrams: grams, message: message);
  }
}
