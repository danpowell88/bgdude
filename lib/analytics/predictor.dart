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
}

class GlucosePredictor {
  GlucosePredictor({
    this.stepMinutes = 5,
    this.horizonMinutes = 240,
    this.momentumDecayMinutes = 30,
    CarbModel? carbModel,
    InsulinModel? insulinModel,
  })  : _carbModel = carbModel ?? const CarbModel(),
        _iob = IobCalculator(model: insulinModel ?? InsulinModel.rapidActing);

  final int stepMinutes;
  final int horizonMinutes;

  /// Momentum (unexplained recent trend) decays to zero over this window.
  final int momentumDecayMinutes;

  final CarbModel _carbModel;
  final IobCalculator _iob;

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

    final steps = horizonMinutes ~/ stepMinutes;
    for (var i = 1; i <= steps; i++) {
      final t = s.now.add(Duration(minutes: i * stepMinutes));

      // Insulin effect over this step: activity(units/min) × ISF × dt.
      final act = _iob.total(boluses, basal, t).activityUnitsPerMin;
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
      if (bg < 39) bg = 39; // CGM floor
      if (bg > 400) bg = 400; // CGM ceiling
      points.add((time: t, mgdl: bg));
    }
    return PredictionLine(label: label, points: points);
  }
}
