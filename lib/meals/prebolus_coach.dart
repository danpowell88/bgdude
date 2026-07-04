/// Pre-bolus coach: recommends how many minutes before eating a saved meal to take
/// the bolus, personalised by the meal's learned absorption curve and the current
/// glucose situation.
///
/// Method: simulate (via [GlucosePredictor.whatIf]) taking the bolus *now* and eating
/// the meal at each candidate lead time (0, 5, …, 30 min). Insulin activity lags carbs
/// (peak ~75 min vs a typical meal peak ~60–90 min), so a longer lead usually lowers
/// the post-meal peak — but waiting is only safe while the pre-meal trajectory stays
/// above the low guard. The recommendation is the longest lead that keeps the whole
/// trajectory safe, with plain-language working shown, mirroring [BolusAdvisor]'s
/// AdviceStep pattern.
library;

import '../analytics/bolus_advisor.dart';
import '../analytics/insulin_math.dart';
import '../analytics/predictor.dart';
import '../core/samples.dart';
import '../core/units.dart';
import 'meal_library.dart';

class PreBolusAdvice {
  const PreBolusAdvice({
    required this.recommendedMinutes,
    required this.bolusAfterEating,
    required this.predictedPeakWithMgdl,
    required this.predictedPeakWithoutMgdl,
    required this.confidence,
    required this.working,
    required this.notes,
  });

  /// Minutes to wait between bolusing and eating. 0 with [bolusAfterEating] false
  /// means "bolus and eat together"; [bolusAfterEating] true means dose after food
  /// (low/falling situations).
  final int recommendedMinutes;
  final bool bolusAfterEating;

  /// Predicted post-meal peak with the recommended lead vs a 0-min lead.
  final double predictedPeakWithMgdl;
  final double predictedPeakWithoutMgdl;

  final AdviceConfidence confidence;
  final List<AdviceStep> working;
  final List<String> notes;
}

class PreBolusCoach {
  PreBolusCoach({
    GlucosePredictor? predictor,
    this.insulinModel = InsulinModel.rapidActing,
    this.lowGuardMgdl = 81, // 4.5 mmol/L
    this.candidateLeads = const [0, 5, 10, 15, 20, 25, 30],
  }) : _predictor = predictor ?? GlucosePredictor();

  final GlucosePredictor _predictor;
  final InsulinModel insulinModel;

  /// The pre-meal trajectory must stay above this for a lead to be considered safe.
  final double lowGuardMgdl;

  final List<int> candidateLeads;

  PreBolusAdvice advise({
    required SavedMeal meal,
    required PredictionState state,
    GlucoseUnit displayUnit = GlucoseUnit.mmol,
  }) {
    final seg = state.settings.segmentAt(state.now);
    final mult = state.context.effectiveMultiplier;
    final bolusUnits = meal.carbsGrams / (seg.carbRatio / mult);
    final working = <AdviceStep>[];
    final notes = <String>[];

    working
      ..add(AdviceStep('Meal', '${meal.emoji} ${meal.name} '
          '(${meal.carbsGrams.toStringAsFixed(0)} g)'))
      ..add(AdviceStep('Learned curve',
          'absorbs over ~${meal.absorptionMinutes} min, peak ~+${meal.peakOffsetMinutes} min'))
      ..add(AdviceStep('Bolus', '${bolusUnits.toStringAsFixed(2)} U'));

    // Low / falling now → dose with or after food, don't wait.
    final fallingFast = state.recentRocMgdlPerMin <= -2.0;
    if (state.currentMgdl < lowGuardMgdl || fallingFast) {
      final reason = state.currentMgdl < lowGuardMgdl
          ? 'Glucose is below ${Mgdl(lowGuardMgdl).display(displayUnit)} ${displayUnit.label}'
          : 'Glucose is falling quickly';
      notes.add('$reason — eat first, bolus with or just after the meal.');
      final peak = _peakForLead(state, meal, bolusUnits, 0);
      return PreBolusAdvice(
        recommendedMinutes: 0,
        bolusAfterEating: true,
        predictedPeakWithMgdl: peak,
        predictedPeakWithoutMgdl: peak,
        confidence: AdviceConfidence.moderate,
        working: working,
        notes: notes,
      );
    }

    // Simulate each candidate lead; keep the longest lead whose pre-meal dip stays
    // above the guard, tracking the peak improvement it buys.
    final peakAtZero = _peakForLead(state, meal, bolusUnits, 0);
    var best = 0;
    var bestPeak = peakAtZero;
    for (final lead in candidateLeads) {
      if (lead == 0) continue;
      final line = _lineForLead(state, meal, bolusUnits, lead);
      final preMealMin = _minBefore(line, state.now.add(Duration(minutes: lead)));
      if (preMealMin < lowGuardMgdl) break; // longer leads only dip further
      final peak = _peakAfter(line, state.now.add(Duration(minutes: lead)));
      if (peak <= bestPeak) {
        best = lead;
        bestPeak = peak;
      }
    }

    // High and rising → lean toward the longest safe lead even if the marginal peak
    // gain flattens out.
    if (state.currentMgdl > 180 && state.recentRocMgdlPerMin > 0.5 && best < 20) {
      final longestSafe = _longestSafeLead(state, meal, bolusUnits);
      if (longestSafe > best) {
        best = longestSafe;
        bestPeak = _peakForLead(state, meal, bolusUnits, best);
        notes.add('Running high and rising — the longer lead gives the insulin a '
            'head start.');
      }
    }

    working.add(AdviceStep('Predicted peak',
        '${Mgdl(bestPeak).display(displayUnit)} with a $best-min lead vs '
        '${Mgdl(peakAtZero).display(displayUnit)} ${displayUnit.label} with none'));

    if (meal.fatProteinHeavy) {
      notes.add('Fat/protein-heavy meal — expect a late tail; an extended/split '
          'bolus may work better than a longer lead.');
    }

    final outcomes = meal.outcomes.length;
    final confidence = outcomes >= 3
        ? AdviceConfidence.high
        : outcomes >= 1
            ? AdviceConfidence.moderate
            : AdviceConfidence.low;
    if (outcomes < 3) {
      notes.add('Only $outcomes logged outcome${outcomes == 1 ? '' : 's'} for this '
          'meal — the curve is still learning.');
    }

    return PreBolusAdvice(
      recommendedMinutes: best,
      bolusAfterEating: false,
      predictedPeakWithMgdl: bestPeak,
      predictedPeakWithoutMgdl: peakAtZero,
      confidence: confidence,
      working: working,
      notes: notes,
    );
  }

  /// Simulated trajectory: bolus now, meal at now+[leadMinutes].
  PredictionLine _lineForLead(
    PredictionState state,
    SavedMeal meal,
    double bolusUnits,
    int leadMinutes,
  ) {
    // whatIf overlays entries at `state.now`; shift the carb entry via a custom list.
    final shifted = PredictionState(
      now: state.now,
      currentMgdl: state.currentMgdl,
      recentRocMgdlPerMin: state.recentRocMgdlPerMin,
      boluses: [
        ...state.boluses,
        BolusEvent(time: state.now, units: bolusUnits),
      ],
      basal: state.basal,
      carbs: [
        ...state.carbs,
        CarbEntry(
          time: state.now.add(Duration(minutes: leadMinutes)),
          grams: meal.carbsGrams,
          absorptionMinutes: meal.absorptionMinutes,
        ),
      ],
      settings: state.settings,
      context: state.context,
    );
    return _predictor.predict(shifted, label: 'lead $leadMinutes');
  }

  double _peakForLead(
    PredictionState state,
    SavedMeal meal,
    double bolusUnits,
    int leadMinutes,
  ) {
    final line = _lineForLead(state, meal, bolusUnits, leadMinutes);
    return _peakAfter(line, state.now.add(Duration(minutes: leadMinutes)));
  }

  int _longestSafeLead(
    PredictionState state,
    SavedMeal meal,
    double bolusUnits,
  ) {
    var longest = 0;
    for (final lead in candidateLeads) {
      final line = _lineForLead(state, meal, bolusUnits, lead);
      final preMealMin = _minBefore(line, state.now.add(Duration(minutes: lead)));
      if (preMealMin >= lowGuardMgdl) longest = lead;
    }
    return longest;
  }

  static double _minBefore(PredictionLine line, DateTime until) {
    var min = double.infinity;
    for (final p in line.points) {
      if (p.time.isAfter(until)) break;
      if (p.mgdl < min) min = p.mgdl;
    }
    return min == double.infinity ? line.points.first.mgdl : min;
  }

  static double _peakAfter(PredictionLine line, DateTime from) {
    var max = double.negativeInfinity;
    for (final p in line.points) {
      if (p.time.isBefore(from)) continue;
      if (p.mgdl > max) max = p.mgdl;
    }
    return max == double.negativeInfinity ? line.points.last.mgdl : max;
  }
}
