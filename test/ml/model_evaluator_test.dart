import 'package:bgdude/ml/model_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = ModelEvaluator();

  group('MARD (TASK-163)', () {
    test('pins mean(|pred-ref|/ref)*100 for a known pair of errors', () {
      // (100->110): |110-100|/100 = 0.10; (200->180): |180-200|/200 = 0.10.
      final eval = evaluator.evaluate(const [
        (reference: 100.0, predicted: 110.0),
        (reference: 200.0, predicted: 180.0),
      ]);
      expect(eval.mardPercent, closeTo(10.0, 1e-9));
    });

    test('a reference of zero (or below) is excluded from the mean', () {
      final withZero = evaluator.evaluate(const [
        (reference: 100.0, predicted: 110.0),
        (reference: 0.0, predicted: 50.0),
      ]);
      final withoutZero = evaluator.evaluate(const [
        (reference: 100.0, predicted: 110.0),
      ]);
      expect(withZero.mardPercent, closeTo(withoutZero.mardPercent, 1e-9));
    });

    test('an empty pair list yields a zero MARD, not NaN/infinity', () {
      final eval = evaluator.evaluate(const []);
      expect(eval.mardPercent, 0.0);
    });

    test('a perfect prediction yields zero MARD', () {
      final eval = evaluator.evaluate(const [
        (reference: 120.0, predicted: 120.0),
      ]);
      expect(eval.mardPercent, 0.0);
    });
  });
}
