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

/// The pure numeric outcome of the dose math (TASK-101): every value and flag the presenter
/// needs to render the working/notes, with **zero string formatting**. Unit-tested directly
/// so the clinical arithmetic is checked without parsing display strings.
class BolusComputation {
  const BolusComputation({
    required this.displayUnit,
    required this.carbsGrams,
    required this.effectiveCr,
    required this.isf,
    required this.mult,
    required this.mealUnits,
    required this.fpu,
    required this.exactMacros,
    required this.fatGrams,
    required this.proteinGrams,
    required this.fatProteinLevel,
    required this.fpuUnits,
    required this.fpuExtendHours,
    required this.currentMgdl,
    required this.targetMgdl,
    required this.iob,
    required this.cgmNoisy,
    required this.currentlyLow,
    required this.correctionAfterIob,
    required this.iobCoveredCorrection,
    required this.ciqHalved,
    required this.ciqSleepNote,
    required this.predictedMinMgdl,
    required this.predictedLowApplied,
    required this.predictedLowSeverity,
    required this.correctionBeforePredCut,
    required this.correctionUnits,
    required this.cap,
    required this.capped,
    required this.total,
    required this.shownMeal,
    required this.shownCorrection,
    required this.fpuOverCap,
    required this.contextConfidence,
    required this.contextReasons,
    required this.confidence,
  });

  final GlucoseUnit displayUnit;
  final double carbsGrams;
  final double effectiveCr;
  final double isf;
  final double mult;

  /// Immediate meal insulin (carbs ÷ CR), pre-cap.
  final double mealUnits;

  final double fpu;
  final bool exactMacros;
  final double fatGrams;
  final double proteinGrams;
  final FatProteinLevel fatProteinLevel;
  final double fpuUnits;
  final int fpuExtendHours;

  final double currentMgdl;
  final double targetMgdl;

  /// Bolus-only IOB subtracted from the correction.
  final double iob;

  final bool cgmNoisy;
  final bool currentlyLow;

  /// Correction right after subtracting IOB (may be negative), as shown in the working.
  final double correctionAfterIob;

  /// The IOB already covered the correction (it was clamped up to 0).
  final bool iobCoveredCorrection;

  /// Control-IQ halved the correction (active + auto-correcting).
  final bool ciqHalved;

  /// Control-IQ Sleep note applies (active, non-auto-correcting, correction present).
  final bool ciqSleepNote;

  final double predictedMinMgdl;
  final bool predictedLowApplied;

  /// 1.0 for a very-low forecast (full cut), 0.5 otherwise.
  final double predictedLowSeverity;

  /// Correction before the predicted-low reduction (to word "reduced by X%").
  final double correctionBeforePredCut;

  /// Final correction after IOB, Control-IQ and predicted-low adjustments.
  final double correctionUnits;

  final double cap;
  final bool capped;

  /// Final, capped, rounded immediate suggestion (meal + correction).
  final double total;
  final double shownMeal;
  final double shownCorrection;

  /// Immediate + extended exceeds the pump max bolus.
  final bool fpuOverCap;

  final double contextConfidence;
  final List<String> contextReasons;
  final AdviceConfidence confidence;
}

class BolusAdvisor {
  BolusAdvisor({GlucosePredictor? predictor, IobCalculator? iobCalculator})
      : _predictor = predictor ?? GlucosePredictor(),
        _injectedIob = iobCalculator;

  final GlucosePredictor _predictor;

  /// An explicitly-injected calculator (tests) overrides the configured curve.
  final IobCalculator? _injectedIob;

  /// P0-4: honour the configured DIA / insulin peak from [TherapySettings].
  IobCalculator _iobFor(TherapySettings s) => _injectedIob ??
      IobCalculator(
        model: InsulinModel(
          durationMinutes: s.durationOfInsulinActionMinutes,
          peakMinutes: s.insulinPeakMinutes,
        ),
      );

  /// 1 fat-protein unit ≈ this many grams of carb for insulin purposes (Pankowska).
  static const double _carbEquivPerFpu = 10;

  // --- Clinical constants (TASK-101), hoisted out of the dose math for testability. ---

  /// Calories per gram of fat / protein, and calories per fat-protein unit — one FPU is
  /// 100 kcal of fat+protein (Warsaw/Pankowska method).
  static const double _fatKcalPerG = 9;
  static const double _proteinKcalPerG = 4;
  static const double _kcalPerFpu = 100;

  /// Extended-bolus duration: the published Pankowska/Warsaw step table (TASK-162) —
  /// 1 FPU→3 h, 2→4 h, 3→5 h, ≥4→8 h. A partial FPU rounds up to the next step
  /// (2.3 FPU extends like 3). The old `(ceil+2).clamp(3,8)` heuristic under-extended
  /// the 4–5 FPU range (6–7 h), risking a rebound rise after big fatty meals.
  /// Public so `FpuCoach` shares the same table instead of drifting.
  static int pankowskaExtendHours(double fpu) => switch (fpu.ceil()) {
        <= 1 => 3,
        2 => 4,
        3 => 5,
        _ => 8,
      };

  /// Control-IQ (auto-correcting) halves a manual correction to avoid stacking.
  static const double _ciqCorrectionFactor = 0.5;

  /// Corrections/doses below this many units are treated as "nothing to do".
  static const double _minActionableUnits = 0.05;

  /// The pump's dose increment: suggestions land on 0.01 U (1/100) steps.
  static const double _pumpIncrementsPerUnit = 100;

  /// Absorbs binary-float error before flooring so an exact increment is kept
  /// (1.23 must floor to 1.23, not 1.22), while a genuine excess still drops.
  static const double _floorEpsilon = 1e-9;

  /// TASK-161: advisory doses round DOWN to the deliverable 0.01 U increment —
  /// never upward; rounding a dose up is the unsafe direction.
  static double _floorToIncrement(double units) =>
      (units * _pumpIncrementsPerUnit + _floorEpsilon).floorToDouble() /
      _pumpIncrementsPerUnit;

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
  ///
  /// [compressionLowSuspected] excludes the current reading from the P0-6 hard low-guard
  /// (a compression low is a false low from lying on the sensor, so it must not block a
  /// legitimate dose). There is no live compression-low detector feeding this yet — see
  /// TASK-6 follow-up; callers pass `false` until one exists.
  BolusAdvice advise(
    PredictionState state, {
    double carbsGrams = 0,
    double fatGrams = 0,
    double proteinGrams = 0,
    FatProteinLevel fatProteinLevel = FatProteinLevel.none,
    bool cgmNoisy = false,
    bool compressionLowSuspected = false,
    GlucoseUnit displayUnit = GlucoseUnit.mmol,
  }) {
    final c = computeBolus(
      state,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      proteinGrams: proteinGrams,
      fatProteinLevel: fatProteinLevel,
      cgmNoisy: cgmNoisy,
      compressionLowSuspected: compressionLowSuspected,
      displayUnit: displayUnit,
    );
    final (working, notes) = _present(c);
    return BolusAdvice(
      correctionUnits: c.correctionUnits,
      mealUnits: c.mealUnits,
      iobUsed: c.iob,
      recommendedUnits: c.total,
      confidence: c.confidence,
      working: working,
      notes: notes,
      fpu: c.fpu,
      fpuUnits: c.fpuUnits,
      fpuExtendHours: c.fpuExtendHours,
    );
  }

  /// The pure dose math (TASK-101): no string formatting. Returns every value and flag the
  /// presenter needs. Directly unit-testable.
  BolusComputation computeBolus(
    PredictionState state, {
    double carbsGrams = 0,
    double fatGrams = 0,
    double proteinGrams = 0,
    FatProteinLevel fatProteinLevel = FatProteinLevel.none,
    bool cgmNoisy = false,
    bool compressionLowSuspected = false,
    GlucoseUnit displayUnit = GlucoseUnit.mmol,
  }) {
    final seg = state.settings.segmentAt(state.now);
    final mult = state.context.effectiveMultiplier;
    final isf = seg.isf / mult;
    final effectiveCr = seg.carbRatio / mult;
    final iob = _bolusIobNow(state);
    var confidence = _baseConfidence(state.context);

    // --- Meal component ---
    final mealUnits = carbsGrams > 0 ? carbsGrams / effectiveCr : 0.0;

    // --- Fat/protein (FPU) extended component ---
    final exactMacros = fatGrams > 0 || proteinGrams > 0;
    final fpu = exactMacros
        ? (fatGrams * _fatKcalPerG + proteinGrams * _proteinKcalPerG) / _kcalPerFpu
        : fatProteinLevel.fpu;
    var fpuUnits = fpu > 0 ? (fpu * _carbEquivPerFpu) / effectiveCr : 0.0;
    fpuUnits = _floorToIncrement(fpuUnits);
    final fpuExtendHours = fpu > 0 ? pankowskaExtendHours(fpu) : 0;

    // --- Correction component ---
    // P0-6: hard low-guard — never suggest a correction while the current reading is
    // already low. A suspected compression low is excluded so it can't block a real dose.
    var correctionUnits = 0.0;
    var correctionAfterIob = 0.0;
    var iobCoveredCorrection = false;
    final currentlyLow = state.currentMgdl < GlucoseThresholds.low &&
        !compressionLowSuspected;
    if (cgmNoisy) {
      confidence = AdviceConfidence.refused;
    } else if (currentlyLow) {
      confidence = AdviceConfidence.moderate;
    } else {
      final rawCorrection = (state.currentMgdl - seg.targetMgdl) / isf;
      correctionAfterIob = rawCorrection - iob;
      if (correctionAfterIob < 0) {
        iobCoveredCorrection = true;
        correctionUnits = 0;
      } else {
        correctionUnits = correctionAfterIob;
      }
    }

    // --- Control-IQ awareness ---
    final ciq = state.controlIq;
    var ciqHalved = false;
    var ciqSleepNote = false;
    if (ciq.enabled) {
      if (ciq.autoCorrects && correctionUnits > _minActionableUnits) {
        correctionUnits *= _ciqCorrectionFactor;
        ciqHalved = true;
        confidence = _downgrade(confidence);
      } else if (!ciq.autoCorrects && correctionUnits > _minActionableUnits) {
        ciqSleepNote = true;
      }
    }

    // --- Predicted-low guardrail ---
    final predictedMin = _predictor.predict(state).minMgdl;
    var predictedLowApplied = false;
    var predictedLowSeverity = 0.0;
    final correctionBeforePredCut = correctionUnits;
    if (predictedMin < GlucoseThresholds.low) {
      predictedLowApplied = true;
      predictedLowSeverity =
          predictedMin < GlucoseThresholds.veryLow ? 1.0 : 0.5;
      correctionUnits *= (1 - predictedLowSeverity);
      confidence = _downgrade(confidence);
    }

    // --- Total + cap ---
    var total = mealUnits + correctionUnits;
    final cap = state.settings.maxBolusUnits;
    var capped = false;
    if (total > cap) {
      capped = true;
      total = cap;
      confidence = _downgrade(confidence);
    }
    if (total < 0) total = 0;
    total = _floorToIncrement(total);

    final shownMeal = mealUnits > total ? total : mealUnits;
    final shownCorrection = (total - shownMeal).clamp(0.0, total).toDouble();
    final fpuOverCap = fpuUnits > 0 && (total + fpuUnits > cap);

    return BolusComputation(
      displayUnit: displayUnit,
      carbsGrams: carbsGrams,
      effectiveCr: effectiveCr,
      isf: isf,
      mult: mult,
      mealUnits: mealUnits,
      fpu: fpu,
      exactMacros: exactMacros,
      fatGrams: fatGrams,
      proteinGrams: proteinGrams,
      fatProteinLevel: fatProteinLevel,
      fpuUnits: fpuUnits,
      fpuExtendHours: fpuExtendHours,
      currentMgdl: state.currentMgdl,
      targetMgdl: seg.targetMgdl,
      iob: iob,
      cgmNoisy: cgmNoisy,
      currentlyLow: currentlyLow,
      correctionAfterIob: correctionAfterIob,
      iobCoveredCorrection: iobCoveredCorrection,
      ciqHalved: ciqHalved,
      ciqSleepNote: ciqSleepNote,
      predictedMinMgdl: predictedMin,
      predictedLowApplied: predictedLowApplied,
      predictedLowSeverity: predictedLowSeverity,
      correctionBeforePredCut: correctionBeforePredCut,
      correctionUnits: correctionUnits,
      cap: cap,
      capped: capped,
      total: total,
      shownMeal: shownMeal,
      shownCorrection: shownCorrection,
      fpuOverCap: fpuOverCap,
      contextConfidence: state.context.confidence,
      contextReasons: state.context.reasons,
      confidence: confidence,
    );
  }

  /// Builds the human-readable working list + notes from a [BolusComputation]. All wording
  /// and formatting lives here so the dose math above stays string-free (TASK-101).
  (List<AdviceStep>, List<String>) _present(BolusComputation c) {
    final unit = c.displayUnit;
    final working = <AdviceStep>[];
    final notes = <String>[];

    // --- Meal ---
    if (c.carbsGrams > 0) {
      working
        ..add(AdviceStep('Carbs', '${c.carbsGrams.toStringAsFixed(0)} g'))
        ..add(AdviceStep(
            'Carb ratio', '1U : ${c.effectiveCr.toStringAsFixed(1)} g'))
        // TASK-161: show the floored value so the working line can never read
        // higher than the suggestion assembled from it.
        ..add(AdviceStep('Meal insulin',
            '${c.carbsGrams.toStringAsFixed(0)} ÷ ${c.effectiveCr.toStringAsFixed(1)} = ${_floorToIncrement(c.mealUnits).toStringAsFixed(2)} U'));
    }

    // --- Fat/protein ---
    if (c.fpu > 0) {
      final src = c.exactMacros
          ? 'fat ${c.fatGrams.toStringAsFixed(0)} g + protein ${c.proteinGrams.toStringAsFixed(0)} g'
          : '${c.fatProteinLevel.label.toLowerCase()} load';
      working
        ..add(AdviceStep('Fat/protein', src))
        ..add(AdviceStep('Fat-protein units', '${c.fpu.toStringAsFixed(1)} FPU'))
        ..add(AdviceStep('Extended insulin',
            '${c.fpu.toStringAsFixed(1)} FPU × ${_carbEquivPerFpu.toStringAsFixed(0)} g ÷ ${c.effectiveCr.toStringAsFixed(1)} = ${c.fpuUnits.toStringAsFixed(2)} U'));
      notes.add(
          'Fat/protein adds ~${c.fpuUnits.toStringAsFixed(1)} U — deliver it extended over '
          '~${c.fpuExtendHours} h (combo/dual-wave), not up front. Expect a delayed rise ~3–5 h '
          'out, then watch for a later low.');
    }

    // --- Correction ---
    if (c.cgmNoisy) {
      notes.add('CGM noisy / in warm-up — no correction from this reading.');
    } else if (c.currentlyLow) {
      working.add(AdviceStep('Glucose',
          '${Mgdl(c.currentMgdl).display(unit)} ${unit.label} (low)'));
      notes.add(
          'You\'re low (${Mgdl(c.currentMgdl).display(unit)} ${unit.label}) — '
          'treat the low first; no correction from this reading.');
      if (c.carbsGrams > 0) {
        notes.add(
            'Treat the low before dosing for the meal, then bolus once you\'re back in range.');
      }
    } else {
      working
        ..add(AdviceStep('Glucose', Mgdl(c.currentMgdl).display(unit)))
        ..add(AdviceStep('Target', Mgdl(c.targetMgdl).display(unit)))
        ..add(AdviceStep('ISF',
            '1U : ${Mgdl(c.isf).display(unit)} ${unit.label}'));
      working.add(AdviceStep('Correction',
          '(${Mgdl(c.currentMgdl).display(unit)} − ${Mgdl(c.targetMgdl).display(unit)}) ÷ ISF − bolus IOB ${c.iob.toStringAsFixed(2)} = ${c.correctionAfterIob.toStringAsFixed(2)} U'));
      if (c.iobCoveredCorrection) {
        notes.add('IOB already covers the correction — none needed.');
      }
    }

    // --- Control-IQ ---
    if (c.ciqHalved) {
      notes.add(
          'Control-IQ is active and auto-corrects highs — correction halved to avoid '
          'stacking. Consider letting the loop work before dosing.');
    } else if (c.ciqSleepNote) {
      notes.add(
          'Control-IQ Sleep mode adjusts basal but does not auto-correct — a manual '
          'correction may be needed.');
    }

    // --- Predicted-low ---
    if (c.predictedLowApplied) {
      if (c.correctionBeforePredCut > 0) {
        notes.add(
            'Predicted low (${Mgdl(c.predictedMinMgdl).display(unit)} ${unit.label}) — correction reduced by ${(c.predictedLowSeverity * 100).round()}%.');
      } else {
        notes.add(
            'Predicted low ahead (${Mgdl(c.predictedMinMgdl).display(unit)} ${unit.label}) — dose with care.');
      }
      if (c.predictedMinMgdl < GlucoseThresholds.veryLow && c.carbsGrams == 0) {
        notes.add('Consider fast carbs rather than insulin.');
      }
    }

    // --- Cap ---
    if (c.capped) {
      notes.add(
          'Capped at max bolus ${c.cap.toStringAsFixed(1)} U (computed ${(c.mealUnits + c.correctionUnits).toStringAsFixed(2)} U).');
    }

    working.add(AdviceStep('Suggested',
        '${c.total.toStringAsFixed(2)} U  (meal ${c.shownMeal.toStringAsFixed(2)} + correction ${c.shownCorrection.toStringAsFixed(2)})'));

    if (c.fpuUnits > 0) {
      working.add(AdviceStep('Now + extended',
          '${c.total.toStringAsFixed(2)} U now + ${c.fpuUnits.toStringAsFixed(2)} U over ${c.fpuExtendHours}h'));
      if (c.fpuOverCap) {
        notes.add(
            'Immediate + extended (${(c.total + c.fpuUnits).toStringAsFixed(1)} U) is over the '
            'max bolus ${c.cap.toStringAsFixed(1)} U — split it across the combo bolus and '
            're-check.');
      }
    }

    if (c.contextConfidence > 0 && c.contextReasons.isNotEmpty) {
      notes.add(
          'Sensitivity context applied (${c.contextReasons.join(', ')}), ×${c.mult.toStringAsFixed(2)}.');
    }

    return (working, notes);
  }

  /// IOB used to trim the correction: **bolus-only** (P0-1). Scheduled basal is
  /// EGP-neutral and, on a Control-IQ pump, already accounted for — counting it here
  /// would shrink corrections and under-dose highs. The forward-prediction path
  /// ([_predictor]) still models full insulin activity from the whole [PredictionState].
  double _bolusIobNow(PredictionState s) =>
      _iobFor(s.settings).fromBoluses(s.boluses, s.now).units;

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
