/// Insulin-sensitivity ("daily readiness") model.
///
/// Learns, from the user's own history, how contextual factors shift their insulin
/// requirement, and outputs a daily resistance multiplier fed into the bolus advisor
/// and morning summary. The label it regresses against is a per-day *sensitivity
/// deviation* derived Autotune-style from glucose response to insulin (see
/// `autotune.dart`): days that needed more insulin than settings predicted → higher
/// resistance.
///
/// Evidence base for the chosen features (see plan / research notes):
///   * short/poor sleep → sensitivity ↓ ~15–25%
///   * low overnight HRV / high resting HR → more insulin resistance
///   * prior-day aerobic exercise → sensitivity ↑ (for hours→24h)
///   * luteal menstrual phase, illness, stress → resistance ↑
///   * alcohol → delayed lows (handled as a predictor bias, not here)
library;

import '../analytics/therapy_settings.dart';
import 'ridge_regression.dart';

export '../analytics/therapy_settings.dart' show SensitivityContext;

/// Contextual features for a given day, already normalised to sensible ranges.
class ContextFeatures {
  const ContextFeatures({
    required this.sleepHours,
    required this.sleepEfficiency,
    required this.overnightHrvRmssd,
    required this.restingHr,
    required this.priorDayExerciseLoad,
    required this.menstrualLutealPhase,
    required this.illnessFlag,
    required this.baselineHrv,
    required this.baselineRestingHr,
    // Extended Health Connect signals (autonomic / illness / activity proxies). Optional
    // so older callers/tests keep working; 0 baselines contribute nothing to the vector.
    this.overnightRespiratoryRate = 0,
    this.spo2 = 0,
    this.bodyTempC = 0,
    this.activeEnergyKcal = 0,
    this.baselineRespiratoryRate = 0,
    this.baselineSpo2 = 0,
    this.baselineBodyTempC = 0,
    this.baselineActiveEnergyKcal = 0,
  });

  final double sleepHours;

  /// 0..1 (asleep / in-bed).
  final double sleepEfficiency;
  final double overnightHrvRmssd;
  final double restingHr;

  /// Normalised training-impulse of the previous day's exercise (0 = none).
  final double priorDayExerciseLoad;

  /// 1.0 if in the luteal phase, else 0.
  final double menstrualLutealPhase;

  /// 1.0 if the user flagged illness, else 0.
  final double illnessFlag;

  /// Personal baselines for relative comparison.
  final double baselineHrv;
  final double baselineRestingHr;

  // Extended signals + their baselines.
  final double overnightRespiratoryRate;
  final double spo2;
  final double bodyTempC;
  final double activeEnergyKcal;
  final double baselineRespiratoryRate;
  final double baselineSpo2;
  final double baselineBodyTempC;
  final double baselineActiveEnergyKcal;

  static double _rel(double v, double base) => base == 0 ? 0 : (v - base) / base;

  /// Feature vector in a fixed order. Relative-to-baseline features generalise across
  /// individuals' absolute ranges; a 0 baseline yields 0 (no signal).
  List<double> toVector() => [
        sleepHours,
        sleepEfficiency,
        _rel(overnightHrvRmssd, baselineHrv),
        _rel(restingHr, baselineRestingHr),
        priorDayExerciseLoad,
        menstrualLutealPhase,
        illnessFlag,
        _rel(overnightRespiratoryRate, baselineRespiratoryRate),
        baselineSpo2 == 0 ? 0 : (spo2 - baselineSpo2), // absolute SpO2 delta (%)
        baselineBodyTempC == 0 ? 0 : (bodyTempC - baselineBodyTempC), // °C delta
        _rel(activeEnergyKcal, baselineActiveEnergyKcal),
      ];

  static const List<String> featureNames = [
    'sleep hours',
    'sleep efficiency',
    'HRV vs baseline',
    'resting HR vs baseline',
    'prior-day exercise',
    'luteal phase',
    'illness',
    'respiratory rate vs baseline',
    'SpO2 delta',
    'body-temp delta',
    'active energy vs baseline',
  ];
}

/// A training example: features for a day + the observed sensitivity deviation.
class SensitivityExample {
  const SensitivityExample({
    required this.features,
    required this.sensitivityDeviation,
    this.weight = 1.0,
  });

  final ContextFeatures features;

  /// Observed multiplier: >1 = needed more insulin than settings (resistant),
  /// <1 = more sensitive. Comes from Autotune-style per-day estimation.
  final double sensitivityDeviation;

  final double weight;
}

class SensitivityModel {
  SensitivityModel({this.model, this.minExamples = 21});

  RidgeModel? model;

  /// Below this many days of data we don't trust a learned model and stay neutral.
  final int minExamples;

  bool get isTrained => model != null;

  /// Fit from history. Uses ridge with moderate shrinkage so a handful of unusual days
  /// can't swing the multiplier wildly.
  void train(List<SensitivityExample> examples) {
    if (examples.length < minExamples) {
      model = null;
      return;
    }
    final x = examples.map((e) => e.features.toVector()).toList();
    final y = examples.map((e) => e.sensitivityDeviation).toList();
    final w = examples.map((e) => e.weight).toList();
    model = const RidgeRegression(lambda: 2.0).fit(x, y, sampleWeights: w);
  }

  /// Produce today's sensitivity context. Confidence scales with data volume and
  /// shrinks the multiplier toward neutral when the model is unsure.
  SensitivityContext contextFor(
    ContextFeatures today, {
    required int trainingDays,
  }) {
    if (model == null) return SensitivityContext.neutral;
    final raw = model!.predict(today.toVector());
    // Clamp to the physiologically plausible band.
    final mult = raw.clamp(0.6, 1.5);
    final confidence = (trainingDays / 60.0).clamp(0.0, 0.9);

    final reasons = _reasons(today);
    return SensitivityContext(
      resistanceMultiplier: mult,
      confidence: confidence,
      reasons: reasons,
    );
  }

  List<String> _reasons(ContextFeatures f) => reasonsFor(f);

  static List<String> reasonsFor(ContextFeatures f) {
    final r = <String>[];
    if (f.sleepHours < 6) r.add('short sleep');
    if (f.baselineHrv > 0 && f.overnightHrvRmssd < f.baselineHrv * 0.85) {
      r.add('low HRV');
    }
    if (f.baselineRestingHr > 0 && f.restingHr > f.baselineRestingHr * 1.08) {
      r.add('elevated resting HR');
    }
    if (f.priorDayExerciseLoad > 0.5) r.add('post-exercise');
    if (f.menstrualLutealPhase > 0.5) r.add('luteal phase');
    if (f.illnessFlag > 0.5) r.add('illness');
    return r;
  }
}

/// A transparent, model-free sensitivity estimate from context, used before enough
/// history exists to train [SensitivityModel]. Each recognised driver nudges the
/// resistance multiplier by a small, literature-motivated amount; the result is
/// clamped and carries modest confidence so it informs without over-committing.
SensitivityContext heuristicSensitivity(ContextFeatures f) {
  var mult = 1.0;
  if (f.sleepHours < 5) {
    mult += 0.20;
  } else if (f.sleepHours < 6) {
    mult += 0.12;
  }
  if (f.baselineHrv > 0 && f.overnightHrvRmssd < f.baselineHrv * 0.85) {
    mult += 0.08;
  }
  if (f.baselineRestingHr > 0 && f.restingHr > f.baselineRestingHr * 1.08) {
    mult += 0.05;
  }
  if (f.menstrualLutealPhase > 0.5) mult += 0.10;
  if (f.illnessFlag > 0.5) mult += 0.15;
  // Elevated body temperature / respiratory rate (illness/stress proxies) → resistance.
  if (f.baselineBodyTempC > 0 && f.bodyTempC > f.baselineBodyTempC + 0.5) {
    mult += 0.10;
  }
  if (f.baselineRespiratoryRate > 0 &&
      f.overnightRespiratoryRate > f.baselineRespiratoryRate * 1.12) {
    mult += 0.05;
  }
  // Prior-day aerobic exercise raises sensitivity (lowers requirement).
  if (f.priorDayExerciseLoad > 0.5) mult -= 0.08;

  final reasons = SensitivityModel.reasonsFor(f);
  if (reasons.isEmpty && mult == 1.0) return SensitivityContext.neutral;
  return SensitivityContext(
    resistanceMultiplier: mult.clamp(0.6, 1.5).toDouble(),
    confidence: 0.5, // informative, not authoritative, pre-training
    reasons: reasons,
  );
}
