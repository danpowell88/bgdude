/// Persists the learned residual model and runs the train → gate → promote cycle.
///
/// A newly trained candidate is only promoted (and persisted as the active model) if it
/// passes the registry's [PromotionGate] AND improves RMSE on the held-out tail over
/// BOTH the deterministic baseline and the currently-active residual model (scored on
/// the same tail) — so a retraining run can never degrade the live forecast, not even
/// relative to the model already running.
library;

import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/therapy_settings.dart';
import '../data/kv_store.dart';
import '../core/samples.dart';
import '../feedback/annotations.dart';
import 'forecast_features.dart';
import 'forecaster.dart';
import 'forecaster_training.dart';
import 'health_features.dart';
import 'model_registry.dart';
import 'residual_gbm_model.dart';

class TrainingOutcome {
  const TrainingOutcome({
    required this.trained,
    required this.promoted,
    this.reasons = const [],
    this.baselineRmse,
    this.candidateRmse,
    this.incumbentRmse,
    this.trainSamples = 0,
  });

  final bool trained;
  final bool promoted;
  final List<String> reasons;
  final double? baselineRmse;
  final double? candidateRmse;

  /// Held-out RMSE of the model that was live when training ran (null when the
  /// forecast was still baseline-only).
  final double? incumbentRmse;
  final int trainSamples;

  static const TrainingOutcome notEnoughData =
      TrainingOutcome(trained: false, promoted: false, reasons: ['not enough data']);
}

/// Loads/saves the active residual model as JSON in shared_preferences, versioned by
/// the feature layout so a layout change discards stale models.
class ForecasterModelStore {
  static const _key = 'residual_model_v2';
  static const _versionKey = 'residual_model_feature_version';

  static Future<ResidualModel> load() async {
    final version = await KvStore.getDouble(_versionKey);
    if (version?.toInt() != ForecastFeatures.version) {
      return const NoResidualModel();
    }
    final raw = await KvStore.getString(_key);
    if (raw == null) return const NoResidualModel();
    try {
      return ResidualGbmModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const NoResidualModel();
    }
  }

  static Future<void> save(ResidualGbmModel model) async {
    await KvStore.setString(_key, jsonEncode(model.toJson()));
    await KvStore.setDouble(_versionKey, ForecastFeatures.version.toDouble());
  }
}

/// Holds the active residual model and runs training. Watched by [forecasterProvider].
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
