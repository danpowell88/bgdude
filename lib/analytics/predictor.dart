/// Deterministic glucose prediction / what-if engine.
///
/// Predicts future glucose as the sum of physiological effects, Loop/oref style:
///   BG(t) = BG(now) + insulin effect + carb effect + momentum
/// Each effect is a summable curve, which makes "what if I took X units / ate Y g"
/// a matter of adding another curve. This is the explainable baseline the ML layer
/// later corrects with a learned residual.
///
/// Produces several labelled scenario lines rather than one confident number, so the
/// UI can show the spread (à la AndroidAPS IOB/COB/UAM/ZT lines).
library;

import '../core/samples.dart';
import 'carb_math.dart';
import 'insulin_math.dart';
import 'therapy_settings.dart';

/// A single predicted glucose trajectory.
class PredictionLine {
  const PredictionLine({
    required this.label,
    required this.points,
  });

  /// e.g. "IOB", "COB", "UAM", "Zero-temp", "What-if +3U".
  final String label;

  /// Predicted (time, mgdl) points at the step cadence.
  final List<({DateTime time, double mgdl})> points;

  double get endMgdl => points.isEmpty ? 0 : points.last.mgdl;
  double get minMgdl =>
      points.isEmpty ? 0 : points.map((p) => p.mgdl).reduce((a, b) => a < b ? a : b);
  double get maxMgdl =>
      points.isEmpty ? 0 : points.map((p) => p.mgdl).reduce((a, b) => a > b ? a : b);
}

/// Approximation of the Control-IQ closed loop for forward simulation.
///
/// Control-IQ changes basal automatically — increasing/suspending it, and (in Standard
/// and Exercise modes) delivering automatic correction boluses — to steer glucose toward
/// a mode-specific band. An open-loop projection that ignores this over-predicts both
/// highs and lows. We model it as a rate-limited proportional pull toward the band: a
/// downward pull above the band (increased basal + auto-corrections) and a gentler upward
/// pull below it (basal suspension can only *withhold* insulin, not add glucose).
///
/// The numbers are deliberately conservative heuristics — enough to attenuate excursions
/// in the right direction and magnitude, not to reproduce the pump's controller exactly.
class ControlIqState {
  const ControlIqState({
    required this.targetCenterMgdl,
    required this.highEdgeMgdl,
    required this.lowEdgeMgdl,
    required this.maxDownPullPerMin,
    required this.maxUpPullPerMin,
    this.enabled = true,
    this.autoCorrects = true,
  });

  /// Closed loop off — no modulation (identical to the pure open-loop forecast).
  static const ControlIqState off = ControlIqState(
    targetCenterMgdl: 0,
    highEdgeMgdl: 0,
    lowEdgeMgdl: 0,
    maxDownPullPerMin: 0,
    maxUpPullPerMin: 0,
    enabled: false,
    autoCorrects: false,
  );

  /// Standard: holds ~112.5–160, auto-corrects toward 110 above 180 → strongest downward
  /// authority (increased basal *and* automatic correction boluses).
  static const ControlIqState standard = ControlIqState(
    targetCenterMgdl: 140,
    highEdgeMgdl: 160,
    lowEdgeMgdl: 70,
    maxDownPullPerMin: 0.6,
    maxUpPullPerMin: 0.35,
  );

  /// Sleep: tighter 112.5–120 band but **no** automatic correction boluses — basal-only,
  /// so the downward authority is weaker than Standard.
  static const ControlIqState sleep = ControlIqState(
    targetCenterMgdl: 112.5,
    highEdgeMgdl: 120,
    lowEdgeMgdl: 75,
    maxDownPullPerMin: 0.35,
    maxUpPullPerMin: 0.35,
    autoCorrects: false,
  );

  /// Exercise: higher 140–160 band and a raised low floor — protects against lows sooner,
  /// corrects highs more gently.
  static const ControlIqState exercise = ControlIqState(
    targetCenterMgdl: 150,
    highEdgeMgdl: 160,
    lowEdgeMgdl: 80,
    maxDownPullPerMin: 0.45,
    maxUpPullPerMin: 0.4,
  );

  final double targetCenterMgdl;
  final double highEdgeMgdl;
  final double lowEdgeMgdl;
  final double maxDownPullPerMin;
  final double maxUpPullPerMin;
  final bool enabled;

  /// Whether this mode delivers automatic correction boluses (Standard/Exercise do;
  /// Sleep is basal-only). Used by the bolus advisor to avoid double-correcting.
  final bool autoCorrects;

  /// Proportional gain: mg/dL of pull rate per mg/dL of distance beyond the band.
  static const double _gainPerMin = 0.015;

  /// The glucose delta the loop contributes over [stepMinutes] at projected [bg].
  /// Negative above the band (basal up / auto-correct), positive below (basal suspended).
  double stepDelta(double bg, int stepMinutes) {
    if (!enabled) return 0;
    if (bg > highEdgeMgdl) {
      final rate =
          (_gainPerMin * (bg - targetCenterMgdl)).clamp(0.0, maxDownPullPerMin);
      return -rate * stepMinutes;
    }
    if (bg < lowEdgeMgdl) {
      final rate =
          (_gainPerMin * (lowEdgeMgdl - bg)).clamp(0.0, maxUpPullPerMin);
      return rate * stepMinutes;
    }
    return 0;
  }
}

/// Inputs describing the current physiological state.
class PredictionState {
  const PredictionState({
    required this.now,
    required this.currentMgdl,
    required this.recentRocMgdlPerMin,
    required this.boluses,
    required this.basal,
    required this.carbs,
    required this.settings,
    this.context = SensitivityContext.neutral,
    this.healthFeatures = const [0.0, 0.0, 0.0],
    this.controlIq = ControlIqState.off,
  });

  final DateTime now;
  final double currentMgdl;

  /// Observed recent rate of change (from CGM), used to seed momentum.
  final double recentRocMgdlPerMin;

  final List<BolusEvent> boluses;
  final List<BasalSegment> basal;
  final List<CarbEntry> carbs;
  final TherapySettings settings;
  final SensitivityContext context;

  /// Acute activity features (steps / post-exercise) from `HealthFeatureSampler`,
  /// fed to the learned residual forecaster. Zeros when no wearable data covers [now].
  final List<double> healthFeatures;

  /// The Control-IQ closed loop, if active — folded into the forward simulation so the
  /// forecast reflects automatic basal changes / corrections. Defaults to off.
  final ControlIqState controlIq;

  PredictionState copyWith({
    List<BolusEvent>? boluses,
    List<BasalSegment>? basal,
    List<CarbEntry>? carbs,
    double? recentRocMgdlPerMin,
  }) =>
      PredictionState(
        now: now,
        currentMgdl: currentMgdl,
        recentRocMgdlPerMin: recentRocMgdlPerMin ?? this.recentRocMgdlPerMin,
        boluses: boluses ?? this.boluses,
        basal: basal ?? this.basal,
        carbs: carbs ?? this.carbs,
        settings: settings,
        context: context,
        healthFeatures: healthFeatures,
        controlIq: controlIq,
      );
}

class GlucosePredictor {
  GlucosePredictor({
    this.stepMinutes = 5,
    this.horizonMinutes = 240,
    this.momentumDecayMinutes = 30,
    CarbModel? carbModel,
    InsulinModel? insulinModel,
  })  : _carbModel = carbModel ?? const CarbModel(),
        _injectedInsulinModel = insulinModel;

  final int stepMinutes;
  final int horizonMinutes;

  /// Momentum (unexplained recent trend) decays to zero over this window.
  final int momentumDecayMinutes;

  final CarbModel _carbModel;

  /// An explicitly-injected insulin model (tests) overrides the configured one.
  final InsulinModel? _injectedInsulinModel;

  /// P0-4: honour the user's configured DIA (duration of insulin action) and insulin
  /// peak from [TherapySettings] instead of a hardcoded 360/75 curve.
  IobCalculator _iobFor(TherapySettings s) => IobCalculator(
        model: _injectedInsulinModel ??
            InsulinModel(
              durationMinutes: s.durationOfInsulinActionMinutes,
              peakMinutes: s.insulinPeakMinutes,
            ),
      );

  /// The primary prediction: insulin + carbs + decaying momentum.
  PredictionLine predict(PredictionState s, {String label = 'Predicted'}) {
    return _simulate(
      s,
      label: label,
      includeCarbs: true,
      includeMomentum: true,
      extraBolus: null,
      extraCarb: null,
    );
  }

  /// The set of scenario lines shown to communicate uncertainty.
  List<PredictionLine> scenarioLines(PredictionState s) => [
        _simulate(s,
            label: 'IOB',
            includeCarbs: false,
            includeMomentum: false,
            extraBolus: null,
            extraCarb: null),
        _simulate(s,
            label: 'COB',
            includeCarbs: true,
            includeMomentum: false,
            extraBolus: null,
            extraCarb: null),
        _simulate(s,
            label: 'UAM',
            includeCarbs: false,
            includeMomentum: true,
            extraBolus: null,
            extraCarb: null),
        _simulate(s,
            label: 'Zero-temp',
            includeCarbs: true,
            includeMomentum: false,
            extraBolus: null,
            extraCarb: null,
            suspendBasal: true),
      ];

  /// What-if: overlay a hypothetical bolus and/or carb entry taken *now*.
  PredictionLine whatIf(
    PredictionState s, {
    double addUnits = 0,
    double addCarbs = 0,
    double carbAbsorptionMinutes = 180,
    String? label,
  }) {
    final extraBolus =
        addUnits > 0 ? BolusEvent(time: s.now, units: addUnits) : null;
    final extraCarb = addCarbs > 0
        ? CarbEntry(
            time: s.now,
            grams: addCarbs,
            absorptionMinutes: carbAbsorptionMinutes.round())
        : null;
    return _simulate(
      s,
      label: label ??
          'What-if'
              '${addUnits > 0 ? ' +${addUnits.toStringAsFixed(1)}U' : ''}'
              '${addCarbs > 0 ? ' +${addCarbs.toStringAsFixed(0)}g' : ''}',
      includeCarbs: true,
      includeMomentum: true,
      extraBolus: extraBolus,
      extraCarb: extraCarb,
    );
  }

  PredictionLine _simulate(
    PredictionState s, {
    required String label,
    required bool includeCarbs,
    required bool includeMomentum,
    required BolusEvent? extraBolus,
    required CarbEntry? extraCarb,
    bool suspendBasal = false,
  }) {
    final seg = s.settings.segmentAt(s.now);
    final mult = s.context.effectiveMultiplier;
    // More resistance => smaller effective ISF (insulin does less). Note CSF = ISF/CR is
    // invariant to the multiplier when it scales ISF and CR proportionally — resistance
    // changes the insulin side, not grams-to-mg/dL; the advisor pulls the carb lever via
    // the effective carb ratio in the dose, not here.
    final isf = seg.isf / mult;
    final csf = carbSensitivityFactor(isf: isf, carbRatio: seg.carbRatio / mult);

    final boluses = [...s.boluses, if (extraBolus != null) extraBolus];
    final carbs = [...s.carbs, if (extraCarb != null) extraCarb];
    final basal = suspendBasal ? const <BasalSegment>[] : s.basal;

    final points = <({DateTime time, double mgdl})>[];
    var bg = s.currentMgdl;
    points.add((time: s.now, mgdl: bg));

    final iob = _iobFor(s.settings);
    final steps = horizonMinutes ~/ stepMinutes;
    for (var i = 1; i <= steps; i++) {
      final t = s.now.add(Duration(minutes: i * stepMinutes));

      // Insulin effect over this step: activity(units/min) × ISF × dt.
      final act = iob.total(boluses, basal, t).activityUnitsPerMin;
      final insulinDelta = -act * isf * stepMinutes;

      // Carb effect over this step.
      var carbDelta = 0.0;
      if (includeCarbs) {
        for (final c in carbs) {
          final minutesAgo = t.difference(c.time).inMinutes.toDouble();
          if (minutesAgo < 0) continue;
          final rate = _carbModel.absorptionRate(
              minutesAgo, c.grams, c.absorptionMinutes.toDouble());
          carbDelta += rate * csf * stepMinutes;
        }
      }

      // Momentum: seed from observed ROC, linearly decaying to zero.
      var momentumDelta = 0.0;
      if (includeMomentum) {
        final elapsed = i * stepMinutes;
        if (elapsed < momentumDecayMinutes) {
          final weight = 1 - elapsed / momentumDecayMinutes;
          momentumDelta = s.recentRocMgdlPerMin * stepMinutes * weight;
        }
      }

      bg += insulinDelta + carbDelta + momentumDelta;

      // Control-IQ closed-loop modulation (skipped for the manual zero-temp hypothetical,
      // which imagines basal off). Applied after the physiological deltas so it reacts to
      // the just-projected level, like the pump's 5-minute control cycle.
      if (!suspendBasal) {
        bg += s.controlIq.stepDelta(bg, stepMinutes);
      }

      if (bg < 39) bg = 39; // CGM floor
      if (bg > 400) bg = 400; // CGM ceiling
      points.add((time: t, mgdl: bg));
    }
    return PredictionLine(label: label, points: points);
  }
}
