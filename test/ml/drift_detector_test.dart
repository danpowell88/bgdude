import 'package:bgdude/ml/drift_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriftDetector.ratios', () {
    test('computes live-RMSE / trained-sigma per horizon', () {
      const detector = DriftDetector();
      final ratios = detector.ratios(
        {30: 10.0, 60: 20.0},
        {30: 5.0, 60: 5.0},
      );
      expect(ratios, {30: 2.0, 60: 4.0});
    });

    test('skips a horizon with no trained sigma (nothing to drift FROM)', () {
      const detector = DriftDetector();
      final ratios = detector.ratios(
        {30: 10.0, 120: 30.0},
        {30: 5.0}, // 120 untrained
      );
      expect(ratios, {30: 2.0});
      expect(ratios.containsKey(120), isFalse);
    });

    test('skips a horizon with no recent live RMSE (nothing to drift WITH)', () {
      const detector = DriftDetector();
      final ratios = detector.ratios({30: 10.0}, {30: 5.0, 60: 5.0});
      expect(ratios, {30: 2.0});
    });

    test('ignores a non-positive stored sigma rather than dividing by it', () {
      const detector = DriftDetector();
      final ratios = detector.ratios({30: 10.0}, {30: 0.0});
      expect(ratios, isEmpty);
    });
  });

  group('DriftDetector.isDriftingNow', () {
    test('true when any horizon meets the threshold', () {
      const detector = DriftDetector();
      expect(detector.isDriftingNow({30: 1.0, 60: kDriftRatioThreshold}), isTrue);
    });

    test('false when every horizon is under the threshold', () {
      const detector = DriftDetector();
      expect(detector.isDriftingNow({30: 1.0, 60: 1.49}), isFalse);
    });

    test('false with no ratios at all', () {
      const detector = DriftDetector();
      expect(detector.isDriftingNow(const {}), isFalse);
    });
  });
}
