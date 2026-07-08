import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/dev/sim_data.dart';
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
        'incumbent (TASK-129)', () async {
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

    test('a late restore never clobbers a newer in-memory model (TASK-129)',
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
