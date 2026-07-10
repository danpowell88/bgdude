import 'dart:convert';
import 'dart:math' as math;

import 'package:bgdude/feedback/retraining.dart';
import 'package:bgdude/ml/forecast_features.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:bgdude/ml/gbm.dart';
import 'package:bgdude/ml/residual_gbm_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build synthetic training samples where the residual target is a nonlinear
/// function of the features, deterministically over a grid.
List<TrainingSample> _samples(
  double Function(double x0, double x1) target, {
  int steps = 10,
}) {
  final base = DateTime(2026, 6, 1);
  final out = <TrainingSample>[];
  var k = 0;
  for (var i = 0; i < steps; i++) {
    for (var j = 0; j < steps; j++) {
      final x0 = -2.0 + 4.0 * i / (steps - 1);
      final x1 = -2.0 + 4.0 * j / (steps - 1);
      out.add(TrainingSample(
        time: base.add(Duration(minutes: 5 * k++)),
        features: [x0, x1],
        target: target(x0, x1),
        weight: 1.0,
      ));
    }
  }
  return out;
}

void main() {
  group('ResidualGbmModel', () {
    test('correct() reduces error vs the zero-residual baseline', () {
      double f(double x0, double x1) => 10 * x0 * x0 - 15 * x1;
      final samples = _samples(f); // 100 samples
      final model = const ResidualGbmTrainer()
          .train({60: samples});

      expect(model.isTrained, isTrue);
      expect(model.trainedHorizons, contains(60));

      var seModel = 0.0;
      var seZero = 0.0;
      for (final s in samples) {
        final c = model.correct(features: s.features, horizonMinutes: 60);
        seModel += math.pow(s.target - c.residual, 2);
        seZero += math.pow(s.target - 0.0, 2);
      }
      expect(seModel, lessThan(0.2 * seZero));
    });

    test('learned sigma is finite, positive and roughly the residual RMSE', () {
      final samples = _samples((x0, x1) => 5 * x0 - 3 * x1);
      final model = const ResidualGbmTrainer().train({30: samples});
      final c = model.correct(features: const [0.0, 0.0], horizonMinutes: 30);
      expect(c.sigma, greaterThan(0.0));
      expect(c.sigma.isFinite, isTrue);
      // Well-fit linear-ish target → small sigma, far below the untrained default.
      expect(c.sigma, lessThan(9 + 30 * 0.30));
    });

    test('sigma comes from held-out residuals when a holdout is provided', () {
      // Model fits the training targets nearly perfectly (training RMSE ≈ 0), but
      // the holdout targets are offset by a constant 25 mg/dL — an honest sigma
      // must reflect that out-of-sample error, not the training fit.
      double f(double x0, double x1) => 5 * x0 - 3 * x1;
      final samples = _samples(f);
      final holdout = [
        for (final s in samples.take(30))
          (features: s.features, target: f(s.features[0], s.features[1]) + 25),
      ];

      final inSample = const ResidualGbmTrainer().train({30: samples});
      final outSample = const ResidualGbmTrainer()
          .train({30: samples}, holdoutByHorizon: {30: holdout});

      final sigmaIn =
          inSample.correct(features: const [0.0, 0.0], horizonMinutes: 30).sigma;
      final sigmaOut =
          outSample.correct(features: const [0.0, 0.0], horizonMinutes: 30).sigma;

      expect(sigmaOut, closeTo(25, 5));
      expect(sigmaOut, greaterThan(sigmaIn));
    });

    test('thin holdout falls back to training RMSE', () {
      double f(double x0, double x1) => 5 * x0 - 3 * x1;
      final samples = _samples(f);
      final thin = [
        for (final s in samples.take(5)) // < minHoldoutForSigma (20)
          (features: s.features, target: f(s.features[0], s.features[1]) + 50),
      ];
      final withThin = const ResidualGbmTrainer()
          .train({30: samples}, holdoutByHorizon: {30: thin});
      final without = const ResidualGbmTrainer().train({30: samples});
      expect(
        withThin.correct(features: const [0.0, 0.0], horizonMinutes: 30).sigma,
        without.correct(features: const [0.0, 0.0], horizonMinutes: 30).sigma,
      );
    });

    test('untrained horizon returns residual 0 and a larger, widening sigma', () {
      final samples = _samples((x0, x1) => x0 - x1);
      final model = const ResidualGbmTrainer().train({60: samples});

      // 120 was never trained.
      final c120 = model.correct(features: const [1.0, 1.0], horizonMinutes: 120);
      expect(c120.residual, 0.0);
      // The untrained-horizon path delegates to the single shared
      // fallbackSigma, not its own copy of the widening formula.
      expect(c120.sigma, closeTo(fallbackSigma(120), 1e-9));

      final c30 = model.correct(features: const [1.0, 1.0], horizonMinutes: 30);
      expect(c30.residual, 0.0);
      expect(c30.sigma, closeTo(fallbackSigma(30), 1e-9));
      // Sigma widens with horizon for untrained horizons.
      expect(c120.sigma, greaterThan(c30.sigma));
    });

    test('skips horizons with too few samples (<50) — left untrained', () {
      final few = _samples((x0, x1) => x0 * x1, steps: 6); // 36 < 50
      final many = _samples((x0, x1) => x0 * x1); // 100

      final model =
          const ResidualGbmTrainer().train({30: few, 60: many});
      expect(model.trainedHorizons, contains(60));
      expect(model.trainedHorizons, isNot(contains(30)));

      // The skipped horizon behaves like untrained.
      final c = model.correct(features: const [0.5, 0.5], horizonMinutes: 30);
      expect(c.residual, 0.0);
      expect(c.sigma, closeTo(9 + 30 * 0.30, 1e-9));
    });

    test('isTrained is false when no horizon has enough data', () {
      final few = _samples((x0, x1) => x0 + x1, steps: 5); // 25 samples
      final model = const ResidualGbmTrainer().train({60: few});
      expect(model.isTrained, isFalse);
    });

    test('JSON round-trip reproduces residual and sigma exactly', () {
      final samples = _samples((x0, x1) => 8 * x0 * x0 - 4 * x1);
      final model =
          const ResidualGbmTrainer().train({30: samples, 60: samples});

      final restored = ResidualGbmModel.fromJson(
              jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>)
          as ResidualGbmModel;

      expect(restored.isTrained, isTrue);
      expect(restored.trainedHorizons.toSet(), model.trainedHorizons.toSet());

      for (final feats in const [
        [0.0, 0.0],
        [1.5, -1.0],
        [-2.0, 2.0],
      ]) {
        for (final h in const [30, 60, 120]) {
          final a = model.correct(features: feats, horizonMinutes: h);
          final b = restored.correct(features: feats, horizonMinutes: h);
          expect(b.residual, a.residual);
          expect(b.sigma, a.sigma);
        }
      }
    });
  });

  group('trainingSigma (per-horizon sigma introspection)', () {
    test('returns null for an untrained horizon', () {
      final samples = _samples((x0, x1) => x0 - x1);
      final model = const ResidualGbmTrainer().train({60: samples});
      expect(model.trainingSigma(120), isNull);
    });

    test('returns null when no horizon has enough data to train', () {
      final few = _samples((x0, x1) => x0 + x1, steps: 5); // 25 < 50
      final model = const ResidualGbmTrainer().train({60: few});
      expect(model.trainingSigma(60), isNull);
    });

    test('returns the same sigma correct() reports for a trained horizon', () {
      final samples = _samples((x0, x1) => 5 * x0 - 3 * x1);
      final model = const ResidualGbmTrainer().train({30: samples});

      final sigma = model.trainingSigma(30);
      expect(sigma, isNotNull);
      expect(sigma,
          model.correct(features: const [0.0, 0.0], horizonMinutes: 30).sigma);
    });
  });

  group('featureImportance (TASK-142)', () {
    test('surfaces the informative feature above the one that never mattered',
        () {
      // Target depends only on x0; x1 is not used anywhere in `f`.
      final samples = _samples((x0, x1) => 10 * x0);
      final model = const ResidualGbmTrainer().train({60: samples});
      final holdout = [
        for (final s in samples) (features: s.features, target: s.target),
      ];

      final importance = model.featureImportance(60, holdout);

      expect(importance, isNotNull);
      expect(importance![0], greaterThan(importance[1]!));
    });

    test('returns null for an untrained horizon', () {
      final samples = _samples((x0, x1) => x0 + x1);
      final model = const ResidualGbmTrainer().train({60: samples});
      final holdout = [
        for (final s in samples) (features: s.features, target: s.target),
      ];
      expect(model.featureImportance(30, holdout), isNull);
    });

    test('returns null for an empty holdout', () {
      final samples = _samples((x0, x1) => x0 + x1);
      final model = const ResidualGbmTrainer().train({60: samples});
      expect(model.featureImportance(60, const []), isNull);
    });
  });

  group('persistence hardening', () {
    Map<String, dynamic> trainedBlob() {
      final samples = _samples((x0, x1) => 8 * x0 * x0 - 4 * x1);
      final model = const ResidualGbmTrainer().train({30: samples});
      return jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>;
    }

    test('toJson embeds schema + feature versions', () {
      final j = trainedBlob();
      expect(j['schema'], ResidualGbmModel.schemaVersion);
      expect(j['featureVersion'], ForecastFeatures.version);
    });

    test('a stale feature version decodes to NoResidualModel (fail safe)', () {
      final j = trainedBlob()..['featureVersion'] = ForecastFeatures.version - 1;
      expect(ResidualGbmModel.fromJson(j), isA<NoResidualModel>());
    });

    test('an unknown schema decodes to NoResidualModel', () {
      final j = trainedBlob()..['schema'] = 99;
      expect(ResidualGbmModel.fromJson(j), isA<NoResidualModel>());
    });

    test('a corrupted child index throws ModelFormatException at LOAD time', () {
      final j = trainedBlob();
      final tree = ((((j['models'] as Map).values.first
              as Map)['trees'] as List)
          .first as Map)['nodes'] as List;
      // Find an internal node and point its left child out of range.
      final internal = tree
          .cast<Map<String, dynamic>>()
          .firstWhere((n) => (n['f'] as num) >= 0);
      internal['l'] = 9999;
      expect(() => ResidualGbmModel.fromJson(j),
          throwsA(isA<ModelFormatException>()));
    });

    test('a split feature beyond the layout width throws at LOAD time', () {
      // The persisted model claims a split on a feature slot the live vector
      // (ForecastFeatures.names.length wide) does not have — the old code only
      // failed at predict time with a RangeError on the forecast path.
      final j = trainedBlob();
      final tree = ((((j['models'] as Map).values.first
              as Map)['trees'] as List)
          .first as Map)['nodes'] as List;
      final internal = tree
          .cast<Map<String, dynamic>>()
          .firstWhere((n) => (n['f'] as num) >= 0);
      internal['f'] = ForecastFeatures.names.length; // one past the end
      expect(() => ResidualGbmModel.fromJson(j),
          throwsA(isA<ModelFormatException>()));
    });

    test('a non-integer horizon key throws ModelFormatException', () {
      final j = trainedBlob();
      final models = j['models'] as Map;
      final blob = models.values.first;
      models
        ..clear()
        ..['not-a-number'] = blob;
      expect(() => ResidualGbmModel.fromJson(j),
          throwsA(isA<ModelFormatException>()));
    });
  });
}
