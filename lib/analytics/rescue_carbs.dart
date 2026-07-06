/// Hypo-treatment helper: how many fast carbs to get back to target, accounting for the
/// insulin still on board and any predicted further drop. 15-15-rule aware — it won't
/// suggest less than a meaningful rescue when you're genuinely low, and it caps
/// over-treatment.
///
/// Pure logic; the caller supplies the current reading, the context-adjusted ISF/CR, IOB,
/// and (optionally) the predicted nadir from the forecaster.
library;

import '../core/units.dart';

class RescueCarbAdvice {
  const RescueCarbAdvice({
    required this.grams,
    required this.urgent,
    required this.reason,
    required this.working,
  });

  /// Suggested fast carbs, grams (0 = none needed).
  final double grams;
  final bool urgent;
  final String reason;
  final List<String> working;

  bool get needed => grams > 0;
}

class RescueCarbCalculator {
  const RescueCarbCalculator({
    this.minRescueGrams = 15,
    this.roundToGrams = 5,
    this.maxRescueGrams = 45,
  });

  final double minRescueGrams;
  final double roundToGrams;
  final double maxRescueGrams;

  /// [currentMgdl] now, [targetMgdl] the correction target, [isf] mg/dL per unit,
  /// [carbRatio] g per unit, [iobUnits] **bolus-only** insulin on board (P0-5:
  /// scheduled basal is EGP-neutral / Control-IQ-managed, so counting it would
  /// over-estimate the insulin still pulling glucose down and over-treat the low),
  /// and optionally
  /// [predictedNadirMgdl] (the min of the forecast). Returns advice, or a "no rescue
  /// needed" result when you're safely above target.
  /// [lowLineMgdl] is the composed effective low line (TASK-147:
  /// `EffectiveLowThreshold.compute` — base line + awareness/alcohol/exercise/weather
  /// modifiers) so rescue advice leads exactly when alerts would. Defaults to the
  /// clinical low; urgency always keys off the clinical very-low regardless.
  RescueCarbAdvice advise({
    required double currentMgdl,
    required double targetMgdl,
    required double isf,
    required double carbRatio,
    required double iobUnits,
    double? predictedNadirMgdl,
    double lowLineMgdl = GlucoseThresholds.low,
    GlucoseUnit unit = GlucoseUnit.mmol,
  }) {
    final csf = carbRatio <= 0 ? 0.0 : isf / carbRatio; // mg/dL rise per gram
    // Worst-case low we're treating toward: the lower of the current reading, the
    // predicted nadir, and the current minus whatever IOB may still pull down.
    final iobDrop = iobUnits * isf;
    final effectiveLow = [
      currentMgdl,
      if (predictedNadirMgdl != null) predictedNadirMgdl,
      currentMgdl - iobDrop * 0.5, // discount: not all IOB lands before carbs act
    ].reduce((a, b) => a < b ? a : b);

    final working = <AdviceLine>[
      AdviceLine('Glucose', '${Mgdl(currentMgdl).display(unit)} ${unit.label}'),
      AdviceLine('Target', '${Mgdl(targetMgdl).display(unit)} ${unit.label}'),
      AdviceLine('IOB', '${iobUnits.toStringAsFixed(1)} U'),
      if (predictedNadirMgdl != null)
        AdviceLine('Predicted low',
            '${Mgdl(predictedNadirMgdl).display(unit)} ${unit.label}'),
    ];

    if (effectiveLow >= targetMgdl && currentMgdl >= lowLineMgdl) {
      return RescueCarbAdvice(
        grams: 0,
        urgent: false,
        reason: 'You\'re at or above target with no low predicted — no rescue needed.',
        working: [for (final l in working) l.text],
      );
    }

    final deficit = (targetMgdl - effectiveLow).clamp(0, 400).toDouble();
    var grams = csf <= 0 ? minRescueGrams : deficit / csf;

    final urgent = effectiveLow < GlucoseThresholds.veryLow ||
        currentMgdl < GlucoseThresholds.veryLow;
    if (grams < minRescueGrams &&
        (currentMgdl < lowLineMgdl ||
            (predictedNadirMgdl ?? currentMgdl) < lowLineMgdl)) {
      grams = minRescueGrams; // 15-15 floor when actually low/heading low
    }
    grams = grams.clamp(0, maxRescueGrams).toDouble();
    grams = (grams / roundToGrams).ceil() * roundToGrams;

    working.add(AdviceLine('Suggested', '${grams.toStringAsFixed(0)} g fast carbs'));

    return RescueCarbAdvice(
      grams: grams,
      urgent: urgent,
      reason: urgent
          ? 'Low — take fast carbs now and recheck in 15 minutes.'
          : 'Heading below target — ${grams.toStringAsFixed(0)} g should bring you back.',
      working: [for (final l in working) l.text],
    );
  }
}

class AdviceLine {
  const AdviceLine(this.label, this.value);
  final String label;
  final String value;
  String get text => '$label: $value';
}
