import 'dart:convert';

import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/dev/sim_data.dart';
import 'package:bgdude/ml/forecast_features.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:bgdude/ml/forecaster_service.dart';
import 'package:bgdude/ml/forecaster_training.dart';
import 'package:bgdude/ml/residual_gbm_model.dart';
import 'package:bgdude/state/forecast_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(KvStore.useMemory);

  final day = SimulatedDay.generate(now: DateTime(2026, 7, 4, 22), seed: 3);

  Future<TrainingOutcome> trainController(ForecasterModelController c) =>
      c.train(
        cgm: day.cgm,
        boluses: day.boluses,
        basal: day.basal,
        carbs: day.carbs,
        settings: day.settings,
        annotations: const [],
        asOf: day.end,
      );

  group('ForecasterModelStore', () {
    test('save → load round-trips a trained model', () async {
      final result = ForecasterTrainer().train(
        cgm: day.cgm,
        boluses: day.boluses,
        basal: day.basal,
        carbs: day.carbs,
        settings: day.settings,
        annotations: const [],
        asOf: day.end,
      );
      expect(result, isNotNull);

      await ForecasterModelStore.save(result!.model);
      final loaded = await ForecasterModelStore.load();
      expect(loaded, isA<ResidualGbmModel>());
      expect(loaded.isTrained, isTrue);
    });

    test('load without a saved model falls back to NoResidualModel', () async {
      expect(await ForecasterModelStore.load(), isA<NoResidualModel>());
    });

    test('load() discards a persisted blob that fails to parse as JSON',
        () async {
      // Simulates on-disk corruption (TASK-128's fail-safe): the blob isn't
      // even valid JSON, so jsonDecode itself throws inside load()'s try.
      await KvStore.setString('residual_model_v3', 'not-json-at-all{{{');
      expect(await ForecasterModelStore.load(), isA<NoResidualModel>());
    });
  });

  group('legacy load migration (pre-TASK-128 two-key layout)', () {
    // Mirrors the private keys `ForecasterModelStore` uses internally --
    // there's no public constant to import, so the literal strings ARE the
    // contract under test (a rename here would need a matching test update).
    const legacyKey = 'residual_model_v2';
    const legacyVersionKey = 'residual_model_feature_version';
    const currentKey = 'residual_model_v3';

    Future<ResidualGbmModel> trainedModel() async {
      final result = ForecasterTrainer().train(
        cgm: day.cgm,
        boluses: day.boluses,
        basal: day.basal,
        carbs: day.carbs,
        settings: day.settings,
        annotations: const [],
        asOf: day.end,
      );
      return result!.model;
    }

    test('migrates a valid legacy blob and re-saves it under the new key',
        () async {
      final model = await trainedModel();
      await KvStore.setDouble(
          legacyVersionKey, ForecastFeatures.version.toDouble());
      await KvStore.setString(legacyKey, jsonEncode(model.toJson()));

      final loaded = await ForecasterModelStore.load();
      expect(loaded, isA<ResidualGbmModel>());
      expect(loaded.isTrained, isTrue);

      // The migration re-saves under the new key so a later load doesn't need
      // the legacy data again.
      expect(await KvStore.getString(currentKey), isNotNull);
    });

    test('a stale legacy feature version is discarded, not migrated',
        () async {
      final model = await trainedModel();
      await KvStore.setDouble(
          legacyVersionKey, (ForecastFeatures.version - 1).toDouble());
      await KvStore.setString(legacyKey, jsonEncode(model.toJson()));

      expect(await ForecasterModelStore.load(), isA<NoResidualModel>());
      expect(await KvStore.getString(currentKey), isNull,
          reason: 'a version mismatch must never be migrated forward');
    });

    test(
        'a current-version marker with no legacy blob falls back to '
        'NoResidualModel', () async {
      await KvStore.setDouble(
          legacyVersionKey, ForecastFeatures.version.toDouble());
      expect(await ForecasterModelStore.load(), isA<NoResidualModel>());
    });

    test('a corrupt legacy blob is discarded, not thrown', () async {
      await KvStore.setDouble(
          legacyVersionKey, ForecastFeatures.version.toDouble());
      await KvStore.setString(legacyKey, 'not-json-at-all{{{');
      expect(await ForecasterModelStore.load(), isA<NoResidualModel>());
    });
  });

  group('ForecasterModelController promotion', () {
    test('first training has no incumbent to compare against', () async {
      final controller = ForecasterModelController();
      await pumpEventQueue();

      final outcome = await trainController(controller);
      expect(outcome.trained, isTrue);
      expect(outcome.incumbentRmse, isNull);
      expect(outcome.candidateRmse, isNotNull);
      expect(outcome.baselineRmse, isNotNull);
    });

    test('identical retrain against a live incumbent is not promoted', () async {
      // Persist an incumbent produced by the exact same (deterministic) trainer
      // configuration the controller uses.
      final incumbent = ForecasterTrainer().train(
        cgm: day.cgm,
        boluses: day.boluses,
        basal: day.basal,
        carbs: day.carbs,
        settings: day.settings,
        annotations: const [],
        asOf: day.end,
      );
      await ForecasterModelStore.save(incumbent!.model);

      final controller = ForecasterModelController();
      await pumpEventQueue();

      // Retraining on identical data yields an identical candidate — RMSE ties
      // the incumbent exactly, and a tie must NOT ship a new model.
      final outcome = await trainController(controller);
      expect(outcome.trained, isTrue);
      expect(outcome.incumbentRmse, isNotNull);
      expect(outcome.candidateRmse, outcome.incumbentRmse);
      expect(outcome.promoted, isFalse);
      expect(outcome.reasons,
          contains('no RMSE improvement over the active model'));
    });

    test(
        'training IMMEDIATELY after construction still A/Bs the on-disk '
        'incumbent', () async {
      final incumbent = ForecasterTrainer().train(
        cgm: day.cgm,
        boluses: day.boluses,
        basal: day.basal,
        carbs: day.carbs,
        settings: day.settings,
        annotations: const [],
        asOf: day.end,
      );
      await ForecasterModelStore.save(incumbent!.model);

      // No pumpEventQueue: train() races the constructor-launched restore. It
      // must await the restore internally, so the persisted incumbent is seen.
      final controller = ForecasterModelController();
      final outcome = await trainController(controller);
      expect(outcome.incumbentRmse, isNotNull,
          reason: 'the A/B must run against the persisted incumbent');
      expect(outcome.promoted, isFalse); // identical retrain never ships
      expect(controller.state.isTrained, isTrue,
          reason: 'the restored incumbent stays live');
    });

    test(
        'not enough data (< 60 cleaned CGM samples) yields '
        'TrainingOutcome.notEnoughData and never touches the incumbent',
        () async {
      final controller = ForecasterModelController();
      await pumpEventQueue();

      // ForecasterTrainer.train() bails out before touching any other
      // argument once the cleaned+sorted CGM series is under 60 samples, so
      // everything else can stay empty/minimal.
      final outcome = await controller.train(
        cgm: const [],
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: day.settings,
        annotations: const [],
        asOf: day.end,
      );

      expect(outcome.trained, isFalse);
      expect(outcome.promoted, isFalse);
      expect(outcome.reasons, contains('not enough data'));
      expect(outcome.importanceByHorizon, isEmpty);
      expect(controller.state, isA<NoResidualModel>(),
          reason: 'a too-thin run must not promote or persist anything');
    });

    test('a late restore never clobbers a newer in-memory model',
        () async {
      // A trained model sits on disk, but by the time the restore lands the
      // controller has already promoted something newer (simulated via the
      // test seam) — the stale on-disk model must NOT be applied.
      final incumbent = ForecasterTrainer().train(
        cgm: day.cgm,
        boluses: day.boluses,
        basal: day.basal,
        carbs: day.carbs,
        settings: day.settings,
        annotations: const [],
        asOf: day.end,
      );
      await ForecasterModelStore.save(incumbent!.model);

      final controller = ForecasterModelController()..debugMarkNewerLocalModel();
      await controller.restored;
      expect(controller.state, isA<NoResidualModel>(),
          reason: 'the restore must be discarded once a local model is newer');
    });
  });
}
