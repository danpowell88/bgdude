import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/sleep_window.dart';
import 'package:bgdude/ml/autotune.dart';
import 'package:bgdude/ml/event_detectors.dart';
import 'package:bgdude/ml/time_of_day_sensitivity.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/samples.dart';

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

    // TASK-232: commit a76487e fixed a crash on empty CGM (the TASK-137 kernel
    // conversion's `sorted.first.time` pre-loop access, masked at the time by a
    // piped exit code) but shipped with no test -- pin the exact bug class here so
    // the guard can't silently regress on the next refactor.
    test('empty CGM returns no candidates, does not throw', () {
      expect(
          () => MealDetector().detect(
              cgm: const [], boluses: const [], basal: const [], settings: settings),
          returnsNormally);
      final out = MealDetector().detect(
          cgm: const [], boluses: const [], basal: const [], settings: settings);
      expect(out, isEmpty);
    });

    test('a single CGM sample returns no candidates, does not throw', () {
      final cgm = trace(DateTime(2026, 7, 4, 13), [120]);
      expect(
          () => MealDetector().detect(
              cgm: cgm, boluses: const [], basal: const [], settings: settings),
          returnsNormally);
      final out = MealDetector()
          .detect(cgm: cgm, boluses: const [], basal: const [], settings: settings);
      expect(out, isEmpty);
    });

    test('an all-gap trace (every step exceeds maxGapMinutes) returns no '
        'candidates, does not throw', () {
      final start = DateTime(2026, 7, 4, 13);
      // 30-min steps: every pair exceeds the kernel's 15-min maxGapMinutes, so
      // every step is a gap break and none carries attribution facts.
      final cgm = [
        for (var i = 0; i < 5; i++)
          CgmSample(time: start.add(Duration(minutes: 30 * i)), mgdl: 100.0 + i),
      ];
      expect(
          () => MealDetector().detect(
              cgm: cgm, boluses: const [], basal: const [], settings: settings),
          returnsNormally);
      final out = MealDetector()
          .detect(cgm: cgm, boluses: const [], basal: const [], settings: settings);
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

  // TASK-232 AC#2: all four AttributionKernel consumers over degenerate CGM input
  // (empty, single-sample, all-gap) in one table-driven sweep. MealDetector is the
  // only one with a pre-loop `.first`/`.last`-style access outside the kernel's own
  // `for (i = 1; ...)` loop (which is itself empty/single-sample-safe by
  // construction) -- CompressionLowDetector, Autotune and the TOD analyzer were
  // already safe, but nothing pinned that before this sweep either.
  group('degenerate CGM input across all 4 kernel consumers (TASK-232)', () {
    final day = DateTime(2026, 7, 4);
    final start = DateTime(2026, 7, 4, 8);

    final degenerateCases = <String, List<CgmSample>>{
      'empty': const [],
      'single sample': trace(start, [120]),
      'all-gap (30-min steps, exceeds the 15-min maxGapMinutes)': [
        for (var i = 0; i < 5; i++)
          CgmSample(time: start.add(Duration(minutes: 30 * i)), mgdl: 100.0 + i),
      ],
    };

    for (final entry in degenerateCases.entries) {
      final cgm = entry.value;

      test('MealDetector: ${entry.key} -> no throw, empty result', () {
        expect(
            () => MealDetector().detect(
                cgm: cgm, boluses: const [], basal: const [], settings: settings),
            returnsNormally);
        expect(
            MealDetector().detect(
                cgm: cgm, boluses: const [], basal: const [], settings: settings),
            isEmpty);
      });

      test('CompressionLowDetector: ${entry.key} -> no throw, empty result', () {
        expect(
            () => CompressionLowDetector().detect(
                  cgm: cgm,
                  boluses: const [],
                  basal: const [],
                  settings: settings,
                  isAsleep: defaultAsleepAt,
                ),
            returnsNormally);
        expect(
            CompressionLowDetector().detect(
              cgm: cgm,
              boluses: const [],
              basal: const [],
              settings: settings,
              isAsleep: defaultAsleepAt,
            ),
            isEmpty);
      });

      test('Autotune.analyseDay: ${entry.key} -> no throw, neutral (1.0) result',
          () {
        expect(
            () => Autotune().analyseDay(
                  day: day,
                  cgm: cgm,
                  boluses: const [],
                  basal: const [],
                  carbs: const [],
                  settings: settings,
                ),
            returnsNormally);
        final r = Autotune().analyseDay(
          day: day,
          cgm: cgm,
          boluses: const [],
          basal: const [],
          carbs: const [],
          settings: settings,
        );
        // No qualifying windows -> the damped-to-1 neutral multiplier, not a crash
        // and not a spurious confident adjustment.
        expect(r.sensitivityMultiplier, 1.0);
      });

      test('TimeOfDaySensitivityAnalyzer.analyseDay: ${entry.key} -> no throw, '
          'no bucket samples', () {
        expect(
            () => TimeOfDaySensitivityAnalyzer().analyseDay(
                  day: day,
                  cgm: cgm,
                  boluses: const [],
                  basal: const [],
                  carbs: const [],
                  settings: settings,
                ),
            returnsNormally);
        final r = TimeOfDaySensitivityAnalyzer().analyseDay(
          day: day,
          cgm: cgm,
          boluses: const [],
          basal: const [],
          carbs: const [],
          settings: settings,
        );
        expect(r, isEmpty);
      });
    }
  });
}
