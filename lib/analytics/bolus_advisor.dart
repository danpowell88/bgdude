/// Bolus advisor: computes a *suggested* correction and/or meal bolus for the user to
/// enter on the pump themselves. It never delivers insulin. Every suggestion carries
/// its full working so the user can sanity-check before dosing.
///
/// Guardrails (physiological safety, not regulatory):
///   * Honour IOB — subtract insulin already working.
///   * If the deterministic predictor forecasts a low within the horizon, suppress or
///     shrink the correction component and say why.
///   * When CGM is noisy / in warm-up, refuse to advise a correction.
///   * Cap the total at the therapy `maxBolusUnits`.
///   * Never suggest a *negative* bolus (that's a carb/BG-rescue situation, surfaced
///     separately).
library;

import '../core/samples.dart';
import '../core/units.dart';
import 'carb_math.dart';
import 'insulin_math.dart';
import 'predictor.dart';
import 'therapy_settings.dart';

enum AdviceConfidence { high, moderate, low, refused }

/// One line of the shown "working".
class AdviceStep {
  const AdviceStep(this.label, this.value);
  final String label;
  final String value;
}

class BolusAdvice {
  const BolusAdvice({
    required this.correctionUnits,
    required this.mealUnits,
    required this.iobUsed,
    required this.recommendedUnits,
    required this.confidence,
    required this.working,
    required this.notes,
  });

  final double correctionUnits;
  final double mealUnits;
  final double iobUsed;

  /// Final capped, guardrailed suggestion.
  final double recommendedUnits;

  final AdviceConfidence confidence;

  /// Ordered breakdown for the UI ("BG 12.4 → target 6.5", "ISF 3.0", ...).
  final List<AdviceStep> working;

  /// Safety caveats ("predicted low — correction reduced", ...).
  final List<String> notes;

  bool get refused => confidence == AdviceConfidence.refused;
}

class BolusAdvisor {
  BolusAdvisor({GlucosePredictor? predictor, IobCalculator? iobCalculator})
      : _predictor = predictor ?? GlucosePredictor(),
        _iob = iobCalculator ?? const IobCalculator();

  final GlucosePredictor _predictor;
  final IobCalculator _iob;

  /// [carbsGrams] is the meal being dosed for (0 for a pure correction).
  /// [cgmNoisy] should be set when recent CGM variance is high or the sensor is in
  /// warm-up — the advisor then refuses to compute a correction from the reading.
  BolusAdvice advise(
    PredictionState state, {
    double carbsGrams = 0,
    bool cgmNoisy = false,
    GlucoseUnit displayUnit = GlucoseUnit.mmol,
  }) {
    final seg = state.settings.segmentAt(state.now);
    final mult = state.context.effectiveMultiplier;
    final isf = seg.isf / mult;
    final effectiveCr = seg.carbRatio / mult;
    final iob = _iobNow(state);

    final working = <AdviceStep>[];
    final notes = <String>[];
    var confidence = _baseConfidence(state.context);

    // --- Meal component ---
    final mealUnits = carbsGrams > 0 ? carbsGrams / effectiveCr : 0.0;
    if (carbsGrams > 0) {
      working
        ..add(AdviceStep('Carbs', '${carbsGrams.toStringAsFixed(0)} g'))
        ..add(AdviceStep(
            'Carb ratio', '1U : ${effectiveCr.toStringAsFixed(1)} g'))
        ..add(AdviceStep('Meal insulin',
            '${carbsGrams.toStringAsFixed(0)} ÷ ${effectiveCr.toStringAsFixed(1)} = ${mealUnits.toStringAsFixed(2)} U'));
    }

    // --- Correction component ---
    var correctionUnits = 0.0;
    if (cgmNoisy) {
      notes.add('CGM noisy / in warm-up — no correction from this reading.');
      confidence = AdviceConfidence.refused;
    } else {
      final bg = state.currentMgdl;
      final target = seg.targetMgdl;
      working
        ..add(AdviceStep('Glucose', Mgdl(bg).display(displayUnit)))
        ..add(AdviceStep('Target', Mgdl(target).display(displayUnit)))
        ..add(AdviceStep('ISF',
            '1U : ${Mgdl(isf).display(displayUnit)} ${displayUnit.label}'));
      final rawCorrection = (bg - target) / isf;
      correctionUnits = rawCorrection - iob;
      working.add(AdviceStep('Correction',
          '(${Mgdl(bg).display(displayUnit)} − ${Mgdl(target).display(displayUnit)}) ÷ ISF − IOB ${iob.toStringAsFixed(2)} = ${correctionUnits.toStringAsFixed(2)} U'));
      if (correctionUnits < 0) {
        notes.add('IOB already covers the correction — none needed.');
        correctionUnits = 0;
      }
    }

    // --- Predicted-low guardrail ---
    final prediction = _predictor.predict(state);
    final predictedMin = prediction.minMgdl;
    if (predictedMin < GlucoseThresholds.low) {
      final severity = predictedMin < GlucoseThresholds.veryLow ? 1.0 : 0.5;
      final before = correctionUnits;
      correctionUnits *= (1 - severity);
      if (before > 0) {
        notes.add(
            'Predicted low (${Mgdl(predictedMin).display(displayUnit)} ${displayUnit.label}) — correction reduced by ${(severity * 100).round()}%.');
        confidence = _downgrade(confidence);
      }
      if (predictedMin < GlucoseThresholds.veryLow && carbsGrams == 0) {
        notes.add('Consider fast carbs rather than insulin.');
      }
    }

    // --- Total + cap ---
    var total = mealUnits + correctionUnits;
    final cap = state.settings.maxBolusUnits;
    if (total > cap) {
      notes.add(
          'Capped at max bolus ${cap.toStringAsFixed(1)} U (computed ${total.toStringAsFixed(2)} U).');
      total = cap;
      confidence = _downgrade(confidence);
    }
    if (total < 0) total = 0;

    // Round to the pump's typical 0.01U increment for display.
    total = (total * 100).roundToDouble() / 100;

    working.add(AdviceStep('Suggested',
        '${total.toStringAsFixed(2)} U  (meal ${mealUnits.toStringAsFixed(2)} + correction ${correctionUnits.toStringAsFixed(2)})'));

    if (state.context.confidence > 0 && state.context.reasons.isNotEmpty) {
      notes.add(
          'Sensitivity context applied (${state.context.reasons.join(', ')}), ×${mult.toStringAsFixed(2)}.');
    }

    return BolusAdvice(
      correctionUnits: correctionUnits,
      mealUnits: mealUnits,
      iobUsed: iob,
      recommendedUnits: total,
      confidence: confidence,
      working: working,
      notes: notes,
    );
  }

  double _iobNow(PredictionState s) =>
      _iob.total(s.boluses, s.basal, s.now).units;

  static AdviceConfidence _baseConfidence(SensitivityContext ctx) {
    if (ctx.confidence >= 0.6) return AdviceConfidence.high;
    if (ctx.confidence >= 0.3) return AdviceConfidence.moderate;
    return AdviceConfidence.high; // neutral context is fine; low ctx just means no adj.
  }

  static AdviceConfidence _downgrade(AdviceConfidence c) => switch (c) {
        AdviceConfidence.high => AdviceConfidence.moderate,
        AdviceConfidence.moderate => AdviceConfidence.low,
        AdviceConfidence.low => AdviceConfidence.low,
        AdviceConfidence.refused => AdviceConfidence.refused,
      };
}
