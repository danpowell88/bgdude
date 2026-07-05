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

import '../core/units.dart';
import 'insulin_math.dart';
import 'predictor.dart';
import 'therapy_settings.dart';

enum AdviceConfidence { high, moderate, low, refused }

/// Qualitative fat/protein load, for when the user can't (or won't) count grams — e.g. a
/// restaurant meal. Maps to a representative fat-protein-unit estimate.
enum FatProteinLevel {
  none,
  low,
  medium,
  high;

  /// Representative fat-protein units. Low ≈ a lean/normal meal, medium ≈ a meat-and-sides
  /// plate, high ≈ pizza / fried / creamy.
  double get fpu => switch (this) {
        FatProteinLevel.none => 0,
        FatProteinLevel.low => 1,
        FatProteinLevel.medium => 2,
        FatProteinLevel.high => 3.5,
      };

  String get label => switch (this) {
        FatProteinLevel.none => 'None',
        FatProteinLevel.low => 'Low',
        FatProteinLevel.medium => 'Medium',
        FatProteinLevel.high => 'High',
      };
}

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
    this.fpu = 0,
    this.fpuUnits = 0,
    this.fpuExtendHours = 0,
  });

  final double correctionUnits;
  final double mealUnits;
  final double iobUsed;

  /// Final capped, guardrailed suggestion for the **immediate** bolus (meal + correction).
  final double recommendedUnits;

  /// Fat-protein units for the meal (0 when no fat/protein given).
  final double fpu;

  /// Insulin attributable to fat/protein, to deliver **extended** (combo/dual-wave) over
  /// [fpuExtendHours], not up front. Kept separate from [recommendedUnits] because it's a
  /// later, slower dose.
  final double fpuUnits;

  /// Suggested hours to extend [fpuUnits] over.
  final int fpuExtendHours;

  /// Immediate + extended, for callers that show a combined figure.
  double get totalWithFpu => recommendedUnits + fpuUnits;

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

  /// 1 fat-protein unit ≈ this many grams of carb for insulin purposes (Pankowska).
  static const double _carbEquivPerFpu = 10;

  /// [carbsGrams] is the meal being dosed for (0 for a pure correction).
  ///
  /// Fat/protein can be given two ways (used for the delayed "pizza effect" rise):
  ///   * exact [fatGrams] / [proteinGrams], or
  ///   * a qualitative [fatProteinLevel] (low/medium/high) when grams are unknown.
  /// Exact grams win when both are supplied. The resulting insulin is returned separately
  /// as [BolusAdvice.fpuUnits] to deliver *extended*, not folded into the immediate dose.
  ///
  /// [cgmNoisy] should be set when recent CGM variance is high or the sensor is in
  /// warm-up — the advisor then refuses to compute a correction from the reading.
  BolusAdvice advise(
    PredictionState state, {
    double carbsGrams = 0,
    double fatGrams = 0,
    double proteinGrams = 0,
    FatProteinLevel fatProteinLevel = FatProteinLevel.none,
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

    // --- Fat/protein (FPU) extended component ---
    // Fat and protein cause a delayed, prolonged rise carb-counting misses. Estimate
    // fat-protein units from exact grams, else from the qualitative level, and convert to
    // an insulin amount to deliver *extended* (combo/dual-wave), separate from the dose now.
    final exactMacros = fatGrams > 0 || proteinGrams > 0;
    final fpu = exactMacros
        ? (fatGrams * 9 + proteinGrams * 4) / 100.0
        : fatProteinLevel.fpu;
    var fpuUnits = fpu > 0 ? (fpu * _carbEquivPerFpu) / effectiveCr : 0.0;
    fpuUnits = (fpuUnits * 100).roundToDouble() / 100;
    final fpuExtendHours = fpu > 0 ? (fpu.ceil() + 2).clamp(3, 8) : 0;
    if (fpu > 0) {
      final src = exactMacros
          ? 'fat ${fatGrams.toStringAsFixed(0)} g + protein ${proteinGrams.toStringAsFixed(0)} g'
          : '${fatProteinLevel.label.toLowerCase()} load';
      working
        ..add(AdviceStep('Fat/protein', src))
        ..add(AdviceStep('Fat-protein units', '${fpu.toStringAsFixed(1)} FPU'))
        ..add(AdviceStep('Extended insulin',
            '${fpu.toStringAsFixed(1)} FPU × ${_carbEquivPerFpu.toStringAsFixed(0)} g ÷ ${effectiveCr.toStringAsFixed(1)} = ${fpuUnits.toStringAsFixed(2)} U'));
      notes.add(
          'Fat/protein adds ~${fpuUnits.toStringAsFixed(1)} U — deliver it extended over '
          '~$fpuExtendHours h (combo/dual-wave), not up front. Expect a delayed rise ~3–5 h '
          'out, then watch for a later low.');
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

    // --- Control-IQ awareness ---
    // When the closed loop is running it changes basal automatically. In Standard /
    // Exercise it also delivers automatic correction boluses, so a full manual correction
    // on top risks stacking into a low — halve it and say why. In Sleep it won't
    // auto-correct, so a manual correction is more likely warranted (just flag it).
    final ciq = state.controlIq;
    if (ciq.enabled) {
      if (ciq.autoCorrects && correctionUnits > 0.05) {
        correctionUnits *= 0.5;
        notes.add(
            'Control-IQ is active and auto-corrects highs — correction halved to avoid '
            'stacking. Consider letting the loop work before dosing.');
        confidence = _downgrade(confidence);
      } else if (!ciq.autoCorrects && correctionUnits > 0.05) {
        notes.add(
            'Control-IQ Sleep mode adjusts basal but does not auto-correct — a manual '
            'correction may be needed.');
      }
    }

    // --- Predicted-low guardrail ---
    // Always surface a predicted low, even when there is no correction to trim —
    // the user deciding on a meal bolus needs to know either way.
    final prediction = _predictor.predict(state);
    final predictedMin = prediction.minMgdl;
    if (predictedMin < GlucoseThresholds.low) {
      final severity = predictedMin < GlucoseThresholds.veryLow ? 1.0 : 0.5;
      final before = correctionUnits;
      correctionUnits *= (1 - severity);
      if (before > 0) {
        notes.add(
            'Predicted low (${Mgdl(predictedMin).display(displayUnit)} ${displayUnit.label}) — correction reduced by ${(severity * 100).round()}%.');
      } else {
        notes.add(
            'Predicted low ahead (${Mgdl(predictedMin).display(displayUnit)} ${displayUnit.label}) — dose with care.');
      }
      confidence = _downgrade(confidence);
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

    // Show the breakdown of the (possibly capped) total, so meal + correction always
    // sums to the suggested figure rather than the pre-cap amounts.
    final shownMeal = mealUnits > total ? total : mealUnits;
    final shownCorrection = (total - shownMeal).clamp(0.0, total);
    working.add(AdviceStep('Suggested',
        '${total.toStringAsFixed(2)} U  (meal ${shownMeal.toStringAsFixed(2)} + correction ${shownCorrection.toStringAsFixed(2)})'));

    if (fpuUnits > 0) {
      working.add(AdviceStep('Now + extended',
          '${total.toStringAsFixed(2)} U now + ${fpuUnits.toStringAsFixed(2)} U over ${fpuExtendHours}h'));
      if (total + fpuUnits > cap) {
        notes.add(
            'Immediate + extended (${(total + fpuUnits).toStringAsFixed(1)} U) is over the '
            'max bolus ${cap.toStringAsFixed(1)} U — split it across the combo bolus and '
            're-check.');
      }
    }

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
      fpu: fpu,
      fpuUnits: fpuUnits,
      fpuExtendHours: fpuExtendHours,
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
