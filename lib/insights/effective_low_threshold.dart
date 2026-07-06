/// The ONE composed low-line policy (TASK-147). Every surface that needs to know
/// where "low" starts — alert thresholds, rescue-carb advice, the pre-bolus safety
/// guard — goes through [EffectiveLowThreshold.compute] so coaching can never advise
/// into a situation the app would alert on.
///
/// Composition: start from the user's base low line, add the impaired-awareness bump,
/// then take the max with each situational raise (alcohol, exercise, weather) — the
/// modifiers lead with the strongest single reason rather than stacking.
library;

import 'dart:math' as math;

import '../feedback/annotations.dart';
import '../profile/user_profile.dart';
import '../weather/weather.dart';
import 'alcohol_watch.dart';
import 'exercise_mode.dart';

class EffectiveLowThreshold {
  const EffectiveLowThreshold({required this.mgdl, required this.reasons});

  /// The composed low line, mg/dL. Never below the base the caller passed in.
  final double mgdl;

  /// Human-readable descriptions of the modifiers active right now (empty when the
  /// base line applies unmodified). Shown in advice working/diagnostics.
  final List<String> reasons;

  /// Compose the effective low line at [now] from [base] (the user's low alert line
  /// for the current time-of-day band) and the active safety modifiers:
  /// impaired-awareness risk (older age, long-standing diabetes), a recent alcohol
  /// annotation (delayed lows), an announced exercise session (including its
  /// post-exercise tail), and hot/cold ambient weather.
  static EffectiveLowThreshold compute({
    required double base,
    required UserProfile profile,
    required Iterable<Annotation> annotations,
    ExercisePlan? exercisePlan,
    double? tempC,
    required DateTime now,
  }) {
    final reasons = <String>[];

    final hypoBump = const HypoAwarenessRisk().lowThresholdBump(profile, now);
    var mgdl = base + hypoBump;
    if (hypoBump > 0) {
      reasons.add('impaired-awareness risk (+${hypoBump.round()})');
    }

    const alcohol = AlcoholWatch();
    if (alcohol.activeAt(annotations, now)) {
      mgdl = math.max(mgdl, base + alcohol.lowBumpMgdl);
      reasons.add('alcohol — delayed lows (+${alcohol.lowBumpMgdl.round()})');
    }

    if (exercisePlan != null && exercisePlan.affectsAt(now)) {
      final bump = const ExerciseModeCoach().lowBump(exercisePlan.type);
      mgdl = math.max(mgdl, base + bump);
      reasons.add('exercise session (+${bump.round()})');
    }

    final weatherBump = const WeatherRiskModifier().lowThresholdBump(tempC);
    if (weatherBump > 0) {
      mgdl = math.max(mgdl, base + weatherBump);
      reasons.add('${tempC != null && tempC <= 5 ? 'cold' : 'hot'} weather '
          '(+${weatherBump.round()})');
    }

    return EffectiveLowThreshold(mgdl: mgdl, reasons: reasons);
  }
}
