import 'dart:convert';
import 'dart:math' as math;

import 'package:bgdude/feedback/retraining.dart';
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

    test('untrained horizon returns residual 0 and a larger, widening sigma', () {
      final samples = _samples((x0, x1) => x0 - x1);
      final model = const ResidualGbmTrainer().train({60: samples});

      // 120 was never trained.
      final c120 = model.correct(features: const [1.0, 1.0], horizonMinutes: 120);
      expect(c120.residual, 0.0);
      expect(c120.sigma, closeTo(9 + 120 * 0.30, 1e-9));

      final c30 = model.correct(features: const [1.0, 1.0], horizonMinutes: 30);
      expect(c30.residual, 0.0);
      expect(c30.sigma, closeTo(9 + 30 * 0.30, 1e-9));
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
          jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>);

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
}
