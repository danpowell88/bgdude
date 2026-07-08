import 'package:bgdude/ml/forecaster.dart';
import 'package:flutter_test/flutter_test.dart';

/// fallbackSigma is the single source for the widening fallback
/// uncertainty — previously copy-pasted at three call sites (NoResidualModel and
/// twice in ResidualGbmModel), which could silently drift out of sync.
void main() {
  group('fallbackSigma', () {
    test('pins the exact widening curve', () {
      expect(fallbackSigma(0), closeTo(9.0, 1e-9));
      expect(fallbackSigma(30), closeTo(18.0, 1e-9));
      expect(fallbackSigma(60), closeTo(27.0, 1e-9));
      expect(fallbackSigma(120), closeTo(45.0, 1e-9));
    });

    test('NoResidualModel.correct uses fallbackSigma, not its own copy', () {
      const model = NoResidualModel();
      for (final horizon in [15, 30, 60, 90, 120]) {
        final result =
            model.correct(features: const [], horizonMinutes: horizon);
        expect(result.residual, 0.0);
        expect(result.sigma, fallbackSigma(horizon));
      }
    });
  });
}
