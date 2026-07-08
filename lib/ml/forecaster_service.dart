/// Persists the learned residual model and runs the train → gate → promote cycle.
///
/// A newly trained candidate is only promoted (and persisted as the active model) if it
/// passes the registry's [PromotionGate] AND improves RMSE on the held-out tail over
/// BOTH the deterministic baseline and the currently-active residual model (scored on
/// the same tail) — so a retraining run can never degrade the live forecast, not even
/// relative to the model already running.
library;

import 'dart:convert';

import '../data/kv_store.dart';
import '../logging/app_log.dart';
import 'forecast_features.dart';
import 'forecaster.dart';
import 'residual_gbm_model.dart';
import 'training_census.dart';

class TrainingOutcome {
  const TrainingOutcome({
    required this.trained,
    required this.promoted,
    this.reasons = const [],
    this.baselineRmse,
    this.candidateRmse,
    this.incumbentRmse,
    this.trainSamples = 0,
    this.census = const TrainingCensus(),
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

  /// TASK-140: per-horizon training-sample counts and health-feature coverage
  /// from this run, so the diagnostics screen can explain why a horizon (or the
  /// whole run) declined to train.
  final TrainingCensus census;

  static const TrainingOutcome notEnoughData =
      TrainingOutcome(trained: false, promoted: false, reasons: ['not enough data']);
}

/// Loads/saves the active residual model as ONE JSON record (TASK-128): the schema
/// and feature-layout versions live inside the blob, so version and model can never
/// desync, and a structurally corrupt blob fails safe to [NoResidualModel] at load
/// time instead of a RangeError at predict time.
class ForecasterModelStore {
  static const _key = 'residual_model_v3';

  // Pre-TASK-128 layout: model blob + feature version in separate keys.
  static const _legacyKey = 'residual_model_v2';
  static const _legacyVersionKey = 'residual_model_feature_version';

  /// Past this serialized size, log a warning — the blob lives in the KV store
  /// and should stay bounded.
  static const int softCapBytes = 200 * 1024;

  static Future<ResidualModel> load() async {
    final raw = await KvStore.getString(_key);
    if (raw == null) return _loadLegacy();
    try {
      return ResidualGbmModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      appLog.error('ml', 'persisted model failed validation — discarding',
          error: e);
      return const NoResidualModel();
    }
  }

  /// One-time migration read of the old two-key layout so an existing trained
  /// incumbent survives the upgrade (re-saved in the new single-record format).
  static Future<ResidualModel> _loadLegacy() async {
    final version = await KvStore.getDouble(_legacyVersionKey);
    if (version?.toInt() != ForecastFeatures.version) {
      return const NoResidualModel();
    }
    final raw = await KvStore.getString(_legacyKey);
    if (raw == null) return const NoResidualModel();
    try {
      final patched = (jsonDecode(raw) as Map<String, dynamic>)
        ..['schema'] = ResidualGbmModel.schemaVersion
        ..['featureVersion'] = ForecastFeatures.version;
      final model = ResidualGbmModel.fromJson(patched);
      if (model is ResidualGbmModel) await save(model);
      return model;
    } catch (e) {
      appLog.error('ml', 'legacy persisted model failed validation — discarding',
          error: e);
      return const NoResidualModel();
    }
  }

  static Future<void> save(ResidualGbmModel model) async {
    final raw = jsonEncode(model.toJson());
    final kb = (raw.length / 1024).toStringAsFixed(0);
    if (raw.length > softCapBytes) {
      appLog.warn('ml',
          'model blob ${kb}KB exceeds the ${softCapBytes ~/ 1024}KB soft cap');
    } else {
      appLog.info('ml', 'model blob saved (${kb}KB)');
    }
    await KvStore.setString(_key, raw);
  }
}
