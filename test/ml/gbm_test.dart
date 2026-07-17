import 'dart:convert';
import 'dart:math' as math;

import 'package:bgdude/ml/gbm.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic grid of samples over [-2, 2]^2 for a known function.
({List<List<double>> x, List<double> y}) _grid(
  double Function(double x0, double x1) f, {
  int steps = 12,
}) {
  final x = <List<double>>[];
  final y = <double>[];
  for (var i = 0; i < steps; i++) {
    for (var j = 0; j < steps; j++) {
      final x0 = -2.0 + 4.0 * i / (steps - 1);
      final x1 = -2.0 + 4.0 * j / (steps - 1);
      x.add([x0, x1]);
      y.add(f(x0, x1));
    }
  }
  return (x: x, y: y);
}

double _rmse(GbmRegressor m, List<List<double>> x, List<double> y) {
  var se = 0.0;
  for (var i = 0; i < x.length; i++) {
    final e = y[i] - m.predict(x[i]);
    se += e * e;
  }
  return math.sqrt(se / x.length);
}

void main() {
  group('GbmRegressor', () {
    test('recovers a nonlinear function with low RMSE', () {
      final data = _grid((x0, x1) => x0 * x0 - 2 * x1);
      final m = GbmRegressor(nEstimators: 120, maxDepth: 3, learningRate: 0.1)
        ..fit(data.x, data.y);

      expect(m.isTrained, isTrue);
      expect(m.treeCount, 120);

      final targetRange = data.y.reduce(math.max) - data.y.reduce(math.min);
      final rmse = _rmse(m, data.x, data.y);
      // Comfortably better than a trivial constant predictor.
      expect(rmse, lessThan(0.1 * targetRange));
    });

    test('captures an axis-aligned feature interaction', () {
      // Additive steps PLUS a joint bonus when both features are positive — the
      // interaction term a purely additive/linear model cannot represent.
      double f(double x0, double x1) =>
          (x0 > 0 ? 10.0 : 0.0) +
          (x1 > 0 ? 5.0 : 0.0) +
          (x0 > 0 && x1 > 0 ? 7.0 : 0.0);
      final data = _grid(f);
      final m = GbmRegressor(nEstimators: 150, maxDepth: 3)..fit(data.x, data.y);
      final targetRange = data.y.reduce(math.max) - data.y.reduce(math.min);
      expect(_rmse(m, data.x, data.y), lessThan(0.1 * targetRange));
    });

    test('predictions stay within a sane bound of the training target range', () {
      final data = _grid((x0, x1) => x0 * x0 - 2 * x1);
      final m = GbmRegressor()..fit(data.x, data.y);
      final lo = data.y.reduce(math.min);
      final hi = data.y.reduce(math.max);
      final span = hi - lo;
      for (final row in data.x) {
        final p = m.predict(row);
        expect(p, greaterThan(lo - span));
        expect(p, lessThan(hi + span));
      }
    });

    test('honours sample weights (down-weighted region fit worse)', () {
      final data = _grid((x0, x1) => x0 * x0 - 2 * x1);
      // Weight rows with x0 < 0 near zero.
      final w = [
        for (final row in data.x) row[0] < 0 ? 0.001 : 1.0,
      ];
      final m = GbmRegressor(nEstimators: 100)
        ..fit(data.x, data.y, sampleWeights: w);

      var seDown = 0.0;
      var nDown = 0;
      var seUp = 0.0;
      var nUp = 0;
      for (var i = 0; i < data.x.length; i++) {
        final e = data.y[i] - m.predict(data.x[i]);
        if (data.x[i][0] < 0) {
          seDown += e * e;
          nDown++;
        } else {
          seUp += e * e;
          nUp++;
        }
      }
      final rmseDown = math.sqrt(seDown / nDown);
      final rmseUp = math.sqrt(seUp / nUp);
      expect(rmseUp, lessThan(rmseDown));
    });

    test('JSON round-trip reproduces predictions exactly', () {
      final data = _grid((x0, x1) => x0 * x0 - 2 * x1);
      final m = GbmRegressor(nEstimators: 40)..fit(data.x, data.y);

      final restored = GbmRegressor.fromJson(
          jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);

      expect(restored.maxDepth, m.maxDepth);
      expect(restored.nEstimators, m.nEstimators);
      expect(restored.learningRate, m.learningRate);
      expect(restored.treeCount, m.treeCount);
      for (final row in data.x) {
        expect(restored.predict(row), m.predict(row));
      }
    });

    test('single-sample fit is a safe constant model', () {
      final m = GbmRegressor()..fit([
            [1.0, 2.0]
          ], [
            5.0
          ]);
      expect(m.predict([1.0, 2.0]), closeTo(5.0, 1e-9));
      expect(m.predict([99.0, -99.0]), closeTo(5.0, 1e-9));
    });

    test(
        'minLeafWeight blocks a split whose child passes on raw row count '
        'alone under heavy weight imbalance', () {
      // Two clusters, 5 rows each, separated by a single feature threshold — the
      // ONLY candidate split available. Left cluster's rows carry a near-zero
      // weight (0.001); right cluster's carry full weight (1.0). Left weight sum
      // is 0.005 — under the old int-count guard (minSamplesLeaf=5), 5 rows on
      // each side would have passed the floor and produced a real split; the
      // weighted floor correctly rejects it since 0.005 << 5.0.
      final x = [
        for (var i = 0; i < 5; i++) [1.0 + i * 0.01],
        for (var i = 0; i < 5; i++) [100.0 + i * 0.01],
      ];
      final y = [
        for (var i = 0; i < 5; i++) 10.0,
        for (var i = 0; i < 5; i++) -10.0,
      ];
      final w = [
        for (var i = 0; i < 5; i++) 0.001,
        for (var i = 0; i < 5; i++) 1.0,
      ];

      final guarded = GbmRegressor(
          maxDepth: 3, nEstimators: 1, learningRate: 1.0, minLeafWeight: 5.0)
        ..fit(x, y, sampleWeights: w);
      // No split clears the weighted floor -> a single root leaf -> identical
      // prediction regardless of which cluster the input comes from.
      expect(guarded.predict([1.0]), closeTo(guarded.predict([100.0]), 1e-9));
      // That shared prediction is the overall weighted mean of y (~-9.98), not
      // either cluster's own mean (10 or -10) — proof it's one leaf, not luck.
      expect(guarded.predict([1.0]), closeTo(-9.98, 0.1));

      // Control: with the floor lowered to allow it, the same data DOES split,
      // and the two clusters predict very differently — confirms the guarded
      // case above is actually exercising the floor, not some unrelated reason
      // the tree stayed flat.
      final unguarded = GbmRegressor(
          maxDepth: 3, nEstimators: 1, learningRate: 1.0, minLeafWeight: 0.001)
        ..fit(x, y, sampleWeights: w);
      expect((unguarded.predict([1.0]) - unguarded.predict([100.0])).abs(),
          greaterThan(15.0));
    });
  });

  group('permutationImportance (TASK-142)', () {
    test('ranks the one informative feature far above pure-noise features', () {
      // y depends ONLY on x0; x1 and x2 are independent random noise the model
      // may pick up on by chance during fitting but that carries no real signal
      // to lose when shuffled.
      final rng = math.Random(7);
      final x = <List<double>>[];
      final y = <double>[];
      for (var i = 0; i < 300; i++) {
        final x0 = rng.nextDouble() * 10 - 5;
        final x1 = rng.nextDouble() * 10 - 5;
        final x2 = rng.nextDouble() * 10 - 5;
        x.add([x0, x1, x2]);
        y.add(x0 * 3);
      }
      final model = GbmRegressor(nEstimators: 80, maxDepth: 3)..fit(x, y);

      final importance = model.permutationImportance(x, y);

      expect(importance.length, 3);
      final informative = importance[0]!;
      final noise1 = importance[1]!;
      final noise2 = importance[2]!;
      expect(informative, greaterThan(noise1));
      expect(informative, greaterThan(noise2));
      // The noise features should cost close to nothing to shuffle.
      expect(noise1, lessThan(informative * 0.2));
      expect(noise2, lessThan(informative * 0.2));
    });

    test('is deterministic for the same seed', () {
      final data = _grid((x0, x1) => x0 * x0 - 2 * x1);
      final model = GbmRegressor(nEstimators: 60, maxDepth: 3)
        ..fit(data.x, data.y);
      final a = model.permutationImportance(data.x, data.y, seed: 11);
      final b = model.permutationImportance(data.x, data.y, seed: 11);
      expect(a, b);
    });

    test('empty holdout returns an empty map, does not throw', () {
      final data = _grid((x0, x1) => x0 + x1);
      final model = GbmRegressor(nEstimators: 20)..fit(data.x, data.y);
      expect(model.permutationImportance(const [], const []), isEmpty);
    });
  });
}
