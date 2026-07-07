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
  SensitivityModel({this.model, this.minExamples = defaultMinExamples});

  /// The single source for the "enough days to learn from" floor — the training
  /// service references it so its own gate can't silently disagree.
  static const int defaultMinExamples = 21;

  /// Candidate L2 penalties tried by leave-one-out cross-validation at train time.
  static const List<double> lambdaGrid = [0.5, 1.0, 2.0, 4.0, 8.0];

  RidgeModel? model;

  /// Below this many days of data we don't trust a learned model and stay neutral.
  final int minExamples;

  /// R²-style out-of-sample skill from leave-one-out CV: 1 − cvMSE / var(y),
  /// clamped to [0, 1]. 0 = no better than predicting the mean. Null until trained.
  double? cvSkill;

  /// The lambda the CV grid search settled on. Null until trained.
  double? chosenLambda;

  /// TASK-21: true once a fit has beaten [heuristicSensitivity] on held-out skill
  /// (see [train]). False whenever [model] is null, whether because there wasn't
  /// enough data or because the fit lost to the heuristic.
  bool beatsHeuristic = false;

  bool get isTrained => model != null;

  /// Expected coefficient sign per feature (physiologically motivated — see the
  /// evidence base in this file's doc comment), in [ContextFeatures.toVector] order.
  /// `-1` = should reduce resistance (raise sensitivity), `1` = should increase it.
  /// A fitted coefficient with the wrong sign is noise the small, correlated
  /// feature set picked up, not a real effect — [_signConstrained] zeroes it.
  static const List<int> _expectedSign = [
    -1, // sleep hours: more sleep -> less resistance
    -1, // sleep efficiency: more efficient sleep -> less resistance
    -1, // HRV vs baseline: higher (better) HRV -> less resistance
    1, // resting HR vs baseline: elevated HR -> more resistance
    -1, // prior-day exercise: more exercise -> less resistance
    1, // luteal phase -> more resistance
    1, // illness -> more resistance
    1, // respiratory rate vs baseline: elevated -> more resistance
    -1, // SpO2 delta: higher SpO2 -> less resistance
    1, // body-temp delta: higher temp -> more resistance
    -1, // active energy vs baseline: more activity -> less resistance
  ];

  static RidgeModel _signConstrained(RidgeModel m) {
    final constrained = [
      for (var i = 0; i < m.weights.length; i++)
        _expectedSign[i] != 0 && m.weights[i] * _expectedSign[i] < 0
            ? 0.0
            : m.weights[i],
    ];
    return RidgeModel(
      weights: constrained,
      bias: m.bias,
      featureMeans: m.featureMeans,
      featureStds: m.featureStds,
    );
  }

  /// Weighted in-sample MSE of the model-free heuristic — the bar a learned model
  /// must clear to be adopted (TASK-21 AC#2). The heuristic isn't fit to this data,
  /// so unlike the ridge model's LOO MSE this needs no held-out split.
  static double _heuristicMse(List<SensitivityExample> examples) {
    var se = 0.0, sw = 0.0;
    for (final e in examples) {
      final pred = heuristicSensitivity(e.features).resistanceMultiplier;
      final err = e.sensitivityDeviation - pred;
      se += e.weight * err * err;
      sw += e.weight;
    }
    return sw > 0 ? se / sw : double.infinity;
  }

  /// Fit from history. The ridge penalty is chosen by weighted leave-one-out CV over
  /// [lambdaGrid] (the datasets here are ~a few dozen rows, so this is cheap), and the
  /// resulting out-of-sample skill drives [contextFor]'s confidence. The fitted model
  /// is only adopted if it beats [heuristicSensitivity] on this same skill measure
  /// (TASK-21 AC#2); otherwise callers fall back to the heuristic (see
  /// `effectiveSensitivityProvider`, which already does this whenever [model] is
  /// null). A model that IS adopted has any wrong-signed coefficient zeroed
  /// (TASK-21 AC#1). TASK-244: [_looMse] applies that SAME sign constraint to every
  /// LOO fold's fit before scoring it, so the adoption gate and [cvSkill] measure the
  /// model that's actually deployed — constraining is a cheap O(features) step per
  /// fold (negligible next to the O(n³) ridge solve itself), so an earlier "too
  /// expensive to constrain every fold" rationale for skipping it was mistaken:
  /// scoring the unconstrained fit while shipping the constrained one meant a fit
  /// could clear the beats-heuristic bar, then have coefficients zeroed post-hoc,
  /// silently deploying a different (and possibly worse-than-heuristic) model.
  void train(List<SensitivityExample> examples) {
    if (examples.length < minExamples) {
      model = null;
      cvSkill = null;
      chosenLambda = null;
      beatsHeuristic = false;
      return;
    }
    final x = examples.map((e) => e.features.toVector()).toList();
    final y = examples.map((e) => e.sensitivityDeviation).toList();
    final w = examples.map((e) => e.weight).toList();

    var bestLambda = lambdaGrid.first;
    var bestMse = double.infinity;
    for (final lambda in lambdaGrid) {
      final mse = _looMse(x, y, w, lambda);
      if (mse < bestMse) {
        bestMse = mse;
        bestLambda = lambda;
      }
    }

    if (bestMse >= _heuristicMse(examples)) {
      // The learned model doesn't beat the simple heuristic on held-out skill —
      // decline to adopt it rather than risk trusting a confidently-wrong fit.
      model = null;
      cvSkill = null;
      chosenLambda = null;
      beatsHeuristic = false;
      return;
    }

    // Skill baseline: predicting the weighted mean scores 0.
    var wSum = 0.0, wy = 0.0;
    for (var i = 0; i < y.length; i++) {
      wSum += w[i];
      wy += w[i] * y[i];
    }
    final mean = wSum > 0 ? wy / wSum : 0.0;
    var varY = 0.0;
    for (var i = 0; i < y.length; i++) {
      varY += w[i] * (y[i] - mean) * (y[i] - mean);
    }
    varY = wSum > 0 ? varY / wSum : 0.0;

    cvSkill = varY <= 0 ? 0.0 : (1 - bestMse / varY).clamp(0.0, 1.0).toDouble();
    chosenLambda = bestLambda;
    model = _signConstrained(
        RidgeRegression(lambda: bestLambda).fit(x, y, sampleWeights: w));
    beatsHeuristic = true;
  }

  /// Weighted leave-one-out mean squared error for one lambda. TASK-244: each fold's
  /// fit is sign-constrained the same way [train] constrains the model it deploys —
  /// this must score the model that will actually ship, not the unconstrained fit.
  static double _looMse(
    List<List<double>> x,
    List<double> y,
    List<double> w,
    double lambda,
  ) {
    var se = 0.0, sw = 0.0;
    for (var i = 0; i < x.length; i++) {
      final xTrain = <List<double>>[];
      final yTrain = <double>[];
      final wTrain = <double>[];
      for (var j = 0; j < x.length; j++) {
        if (j == i) continue;
        xTrain.add(x[j]);
        yTrain.add(y[j]);
        wTrain.add(w[j]);
      }
      final fitted = _signConstrained(
          RidgeRegression(lambda: lambda).fit(xTrain, yTrain, sampleWeights: wTrain));
      final err = y[i] - fitted.predict(x[i]);
      se += w[i] * err * err;
      sw += w[i];
    }
    return sw > 0 ? se / sw : double.infinity;
  }

  /// Produce today's sensitivity context. Confidence combines the model's measured
  /// out-of-sample skill (LOO CV) with a data-volume ramp, so a model that merely
  /// memorised noise reports ~0 confidence no matter how many days it has seen.
  SensitivityContext contextFor(
    ContextFeatures today, {
    required int trainingDays,
  }) {
    if (model == null) return SensitivityContext.neutral;
    final raw = model!.predict(today.toVector());
    // Clamp to the physiologically plausible band.
    final mult = raw.clamp(0.6, 1.5);
    final volume = (trainingDays / 30.0).clamp(0.0, 1.0);
    final confidence = ((cvSkill ?? 0.0) * volume).clamp(0.0, 0.9);

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
