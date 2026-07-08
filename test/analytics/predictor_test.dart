/// predictor.dart:356 clamps a NaN/Infinite forecast point back to
/// currentMgdl -- a NaN fails both the floor/ceiling comparisons that follow it (any
/// comparison against NaN is false), so without this clamp it would slip through
/// unchanged and reach the forecast chart as a broken point. The guard was added
/// but no test drove it directly; the bolus/carb/therapy-settings guards from that same
/// change all got negative tests, this one didn't.
library;

import 'package:bgdude/analytics/predictor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/samples.dart';

void main() {
  final now = DateTime(2026, 7, 4, 12);

  PredictionState stateWithRoc(double roc) => PredictionState(
        now: now,
        currentMgdl: 120,
        recentRocMgdlPerMin: roc,
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: testTherapySettings(),
      );

  group('NaN/Infinite forecast clamp', () {
    test(
        'an infinite recent ROC would blow momentum up to Infinity without the clamp '
        '-- every point stays finite, and clamps back to currentMgdl while momentum '
        'is still active', () {
      final line = GlucosePredictor().predict(stateWithRoc(double.infinity));

      for (final p in line.points) {
        expect(p.mgdl.isFinite, isTrue,
            reason: 'a forecast point must never be NaN/Infinite '
                '(got ${p.mgdl} at ${p.time})');
      }
      // Momentum decays to zero after momentumDecayMinutes (default 30 min = 6 steps
      // @5 min); until then, an infinite ROC forces the clamp every single step.
      expect(line.points.first.mgdl, 120.0);
      expect(line.points[1].mgdl, 120.0,
          reason: 'first simulated step: currentMgdl + Infinity momentum must clamp '
              'back to currentMgdl, not propagate Infinity');
      expect(line.points[6].mgdl, 120.0,
          reason: 'still inside the momentum-decay window (30 min / 6 steps)');
    });

    test('a NaN recent ROC is clamped the same way as Infinite', () {
      final line = GlucosePredictor().predict(stateWithRoc(double.nan));

      for (final p in line.points) {
        expect(p.mgdl.isFinite, isTrue,
            reason: 'a forecast point must never be NaN/Infinite '
                '(got ${p.mgdl} at ${p.time})');
      }
      expect(line.points[1].mgdl, 120.0);
    });

    test('a finite ROC produces a normal (non-clamped-every-step) forecast', () {
      final line = GlucosePredictor().predict(stateWithRoc(1.0));

      for (final p in line.points) {
        expect(p.mgdl.isFinite, isTrue);
      }
      // A modest, finite momentum should NOT force every point back to exactly
      // currentMgdl -- this guards against the test above passing vacuously if the
      // clamp fired unconditionally instead of only on NaN/Infinite.
      expect(line.points[1].mgdl, isNot(120.0));
    });
  });
}
