/// The framework-facing controller for the residual forecaster (TASK-40). Kept out of
/// `lib/ml/` so that layer stays Riverpod-free and `dart test`-able on its own — the pure
/// training/gating logic lives in `ml/forecaster_training.dart` + `ml/model_registry.dart`;
/// this only holds the live model as StateNotifier state and runs the train→gate→promote
/// cycle off the UI isolate.
library;

import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/therapy_settings.dart';
import '../core/samples.dart';
import '../feedback/annotations.dart';
import '../ml/forecaster.dart';
import '../ml/forecaster_service.dart';
import '../ml/forecaster_training.dart';
import '../ml/health_features.dart';
import '../ml/model_registry.dart';

/// Holds the active residual model and runs training. Watched by `forecasterProvider`.
class ForecasterModelController extends StateNotifier<ResidualModel> {
  ForecasterModelController() : super(const NoResidualModel()) {
    _restore();
  }

  final PromotionGate _gate = const PromotionGate();
  TrainingOutcome lastOutcome = const TrainingOutcome(trained: false, promoted: false);

  Future<void> _restore() async {
    state = await ForecasterModelStore.load();
  }

  /// Train from history, gate the candidate, and promote + persist if it wins.
  Future<TrainingOutcome> train({
    required List<CgmSample> cgm,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required List<CarbEntry> carbs,
    required TherapySettings settings,
    required List<Annotation> annotations,
    required DateTime asOf,
    HealthFeatureSampler? health,
  }) async {
    // The in-memory state is version-consistent with the current feature layout
    // (the store discards mismatched versions at load), so it can be scored on the
    // freshly built held-out features. Capture it locally so the isolate closure
    // ships plain model data, not this notifier.
    final incumbent = state;
    // CART/GBM fitting over ~a month of strided samples is CPU-heavy; keep it off
    // the UI isolate so training can't jank the app.
    final result = await Isolate.run(() => ForecasterTrainer().train(
          cgm: cgm,
          boluses: boluses,
          basal: basal,
          carbs: carbs,
          settings: settings,
          annotations: annotations,
          asOf: asOf,
          health: health,
          incumbent: incumbent,
        ));
    if (result == null) {
      lastOutcome = TrainingOutcome.notEnoughData;
      return lastOutcome;
    }

    // Gate against the toughest available incumbent, and require the candidate to
    // actually improve on both the deterministic baseline and the live model —
    // a retrain that is worse than what's already running must never ship.
    final incumbentEval = result.incumbentEval;
    final gate = _gate.evaluate(result.candidateEval,
        incumbent: incumbentEval ?? result.baselineEval);
    final improvesBaseline =
        result.candidateEval.rmseMgdl < result.baselineEval.rmseMgdl;
    final improvesIncumbent = incumbentEval == null ||
        result.candidateEval.rmseMgdl < incumbentEval.rmseMgdl;
    final promoted = gate.pass && improvesBaseline && improvesIncumbent;

    if (promoted) {
      await ForecasterModelStore.save(result.model);
      state = result.model;
    }

    lastOutcome = TrainingOutcome(
      trained: true,
      promoted: promoted,
      reasons: [
        ...gate.reasons,
        if (!improvesBaseline) 'no RMSE improvement over baseline',
        if (!improvesIncumbent) 'no RMSE improvement over the active model',
      ],
      baselineRmse: result.baselineEval.rmseMgdl,
      candidateRmse: result.candidateEval.rmseMgdl,
      incumbentRmse: incumbentEval?.rmseMgdl,
      trainSamples: result.trainSamples,
    );
    return lastOutcome;
  }
}
