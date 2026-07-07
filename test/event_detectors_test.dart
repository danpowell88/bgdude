import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/sleep_window.dart';
import 'package:bgdude/ml/event_detectors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/samples.dart';

void main() {
  final settings = testTherapySettings(maxBolusUnits: 15);

  List<CgmSample> trace(DateTime start, List<double> mgdls) => [
        for (var i = 0; i < mgdls.length; i++)
          CgmSample(time: start.add(Duration(minutes: 5 * i)), mgdl: mgdls[i]),
      ];

  group('MealDetector', () {
    test('detects a sustained unbolused rise as a meal candidate', () {
      // +2 mg/dL/min for 25 min, no insulin on board → clearly a meal.
      final cgm = trace(DateTime(2026, 7, 4, 13), [100, 110, 120, 130, 140, 150]);
      final out = MealDetector().detect(
        cgm: cgm,
        boluses: const [],
        basal: const [],
        settings: settings,
      );
      expect(out, isNotEmpty);
      expect(out.first.estimatedCarbsGrams, greaterThan(0));
      expect(out.first.confidence, greaterThan(0));
    });

    test(
        'TASK-171: a rise with a recent bolus still yields a candidate at the '
        'detector level — coverage is the CONSUMER side job', () {
      // Physiology: insulin only pulls glucose down, so rising THROUGH insulin
      // is even stronger evidence of carbs. The raw detector must keep firing;
      // announcement/coverage suppression lives in ConfirmationService (see
      // confirmation_inbox_test) and MissedBolusDetector.
      final start = DateTime(2026, 7, 4, 13);
      final cgm = trace(start, [100, 110, 120, 130, 140, 150]);
      final out = MealDetector().detect(
        cgm: cgm,
        boluses: [BolusEvent(time: start, units: 4)],
        basal: const [],
        settings: settings,
      );
      expect(out, isNotEmpty);
    });

    test('a flat trace produces no candidate', () {
      final cgm = trace(DateTime(2026, 7, 4, 13), [120, 120, 121, 120, 119, 120]);
      final out = MealDetector().detect(
        cgm: cgm,
        boluses: const [],
        basal: const [],
        settings: settings,
      );
      expect(out, isEmpty);
    });
  });

  group('CompressionLowDetector', () {
    test('detects a sharp asleep dip that rebounds', () {
      // Overnight: 120 → 110 → 80 (nadir) → 108 → 115 at 5-min steps.
      final cgm = trace(DateTime(2026, 7, 4, 2), [120, 110, 80, 108, 115]);
      final out = CompressionLowDetector().detect(
        cgm: cgm,
        boluses: const [],
        basal: const [],
        settings: settings,
        isAsleep: defaultAsleepAt,
      );
      expect(out, isNotEmpty);
      expect(out.first.nadir, 80);
    });

    test('the same dip while awake is not flagged', () {
      final cgm = trace(DateTime(2026, 7, 4, 14), [120, 110, 80, 108, 115]);
      final out = CompressionLowDetector().detect(
        cgm: cgm,
        boluses: const [],
        basal: const [],
        settings: settings,
        isAsleep: defaultAsleepAt,
      );
      expect(out, isEmpty);
    });
  });
}
