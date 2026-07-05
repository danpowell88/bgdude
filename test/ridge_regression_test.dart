import 'package:bgdude/ml/ridge_regression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RidgeRegression', () {
    // Deterministic 2-feature grid.
    final x = <List<double>>[
      for (var i = 0; i < 8; i++)
        for (var j = 0; j < 8; j++) [i.toDouble(), j.toDouble()],
    ];

    test('recovers a noise-free linear function (small lambda)', () {
      final y = [for (final r in x) 3.0 + 2.0 * r[0] - 1.0 * r[1]];
      final model = const RidgeRegression(lambda: 1e-6).fit(x, y);
      for (final probe in const [
        [0.0, 0.0],
        [3.0, 5.0],
        [7.0, 1.0],
      ]) {
        expect(model.predict(probe),
            closeTo(3.0 + 2.0 * probe[0] - 1.0 * probe[1], 1e-6));
      }
    });

    test('larger lambda shrinks standardized coefficients toward zero', () {
      final y = [for (final r in x) 5.0 * r[0]];
      final loose = const RidgeRegression(lambda: 1e-6).fit(x, y);
      final tight = const RidgeRegression(lambda: 500).fit(x, y);
      expect(tight.weights[0].abs(), lessThan(loose.weights[0].abs()));
      // The intercept is unpenalized: heavy shrinkage regresses predictions
      // toward the target mean, not toward zero.
      final meanY = y.reduce((a, b) => a + b) / y.length;
      expect(tight.predict(const [3.5, 3.5]), closeTo(meanY, 1.0));
    });

    test('sample weights steer the fit toward heavy rows', () {
      // Two conflicting clusters for the same inputs; weights pick the winner.
      final xw = [
        [0.0, 0.0],
        [1.0, 0.0],
        [0.0, 0.0],
        [1.0, 0.0],
      ];
      final yw = [0.0, 1.0, 10.0, 11.0];
      final w = [100.0, 100.0, 0.01, 0.01];
      final model = const RidgeRegression(lambda: 1e-6)
          .fit(xw, yw, sampleWeights: w);
      expect(model.predict(const [0.0, 0.0]), closeTo(0.0, 0.1));
      expect(model.predict(const [1.0, 0.0]), closeTo(1.0, 0.1));
    });

    test('constant (zero-variance) feature neither crashes nor contributes', () {
      final xc = [for (final r in x) [r[0], 42.0]];
      final y = [for (final r in x) 2.0 * r[0] + 1.0];
      final model = const RidgeRegression(lambda: 1e-6).fit(xc, y);
      expect(model.predict(const [4.0, 42.0]), closeTo(9.0, 1e-6));
      // Changing the dead feature's value must not move the prediction (its
      // std is 0, so it is neutralized at both fit and predict time).
      expect(model.predict(const [4.0, 999.0]),
          closeTo(model.predict(const [4.0, 42.0]), 1e-6));
    });

    test('JSON round-trip reproduces predictions exactly', () {
      final y = [for (final r in x) 1.5 * r[0] - 0.5 * r[1] + 2];
      final model = const RidgeRegression(lambda: 2.0).fit(x, y);
      final restored = RidgeModel.fromJson(model.toJson());
      for (final probe in const [
        [0.0, 0.0],
        [2.5, 6.0],
      ]) {
        expect(restored.predict(probe), model.predict(probe));
      }
    });
  });
}
