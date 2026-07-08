import 'dart:convert';

import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/health_sync.dart';
import 'package:bgdude/ml/forecaster_training.dart';
import 'package:bgdude/ml/health_features.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ForecasterTrainer dose truncation', () {
    test('doses after a timestep cannot leak into its baseline or features', () {
      // Flat trace ending at 21:35 with a large carb entry (and a bolus) at
      // 21:30. Rows at/after 21:30 have no scoreable outcome (their targets fall
      // beyond the last sample), so *no* surviving row should be able to see the
      // events — training with them present must be byte-identical to training
      // without them. Under a future-leaking baseline, rows shortly before 21:30
      // would predict the carb rise inside their horizon and the results diverge.
      final start = DateTime(2026, 7, 1, 0, 0);
      final cgm = [
        for (var i = 0; i <= 259; i++) // 00:00 .. 21:35
          CgmSample(time: start.add(Duration(minutes: 5 * i)), mgdl: 150),
      ];
      final eventTime = DateTime(2026, 7, 1, 21, 30);
      final settings = TherapySettings.placeholder();
      final asOf = DateTime(2026, 7, 1, 22, 0);

      ForecasterTrainingResult? train(List<CarbEntry> carbs,
              List<BolusEvent> boluses) =>
          ForecasterTrainer(horizons: const [30], strideSamples: 1).train(
            cgm: cgm,
            boluses: boluses,
            basal: const [],
            carbs: carbs,
            settings: settings,
            annotations: const [],
            asOf: asOf,
          );

      final without = train(const [], const []);
      final withFuture = train(
        [CarbEntry(time: eventTime, grams: 100)],
        [BolusEvent(time: eventTime, units: 5)],
      );

      expect(without, isNotNull);
      expect(withFuture, isNotNull);

      // Identical baselines, identical residual targets, identical model.
      expect(withFuture!.baselineEval.rmseMgdl,
          without!.baselineEval.rmseMgdl);
      expect(jsonEncode(withFuture.model.toJson()),
          jsonEncode(without.model.toJson()));

      // And on an event-free flat trace the deterministic baseline is near-exact.
      expect(withFuture.baselineEval.rmseMgdl, lessThan(1.0));
    });
  });

  group('census (TASK-140)', () {
    final start = DateTime(2026, 7, 1, 0, 0);
    final cgm = [
      for (var i = 0; i <= 259; i++) // 00:00 .. 21:35
        CgmSample(time: start.add(Duration(minutes: 5 * i)), mgdl: 150),
    ];
    final settings = TherapySettings.placeholder();
    final asOf = DateTime(2026, 7, 1, 22, 0);

    ForecasterTrainingResult? train({HealthFeatureSampler? health}) =>
        ForecasterTrainer(horizons: const [30], strideSamples: 1).train(
          cgm: cgm,
          boluses: const [],
          basal: const [],
          carbs: const [],
          settings: settings,
          annotations: const [],
          asOf: asOf,
          health: health,
        );

    test('perHorizonSamples matches trainSamples for a single-horizon run', () {
      final result = train();
      expect(result, isNotNull);
      expect(result!.census.perHorizonSamples[30], result.trainSamples);
    });

    test('healthFeatureCoverage is 0 with no health data supplied (not null -- '
        'there were training rows, just none with a signal)', () {
      final result = train();
      expect(result!.census.healthFeatureCoverage, 0.0);
    });

    test('healthFeatureCoverage reflects the fraction of rows with a real '
        'health signal', () {
      final health = HealthFeatureSampler([
        for (var i = 0; i <= 259; i++)
          HealthSample(
            time: start.add(Duration(minutes: 5 * i)),
            type: HealthMetric.steps,
            value: 200,
          ),
      ]);
      final result = train(health: health);
      expect(result!.census.healthFeatureCoverage, greaterThan(0.0));
    });
  });
}
