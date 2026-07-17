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
        'a rise with a recent bolus still yields a candidate at the '
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

    // Commit a76487e fixed a crash on empty CGM (the kernel
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

  group('CgmFaultDetector (TASK-141)', () {
    test('flags an implausible jump between consecutive readings', () {
      final cgm = trace(DateTime(2026, 7, 4, 8), [100, 100, 180, 182, 184]);
      final out = const CgmFaultDetector().detect(cgm);
      expect(out.any((e) => e.kind == CgmFaultKind.jump), isTrue);
    });

    test('a normal rate of change is not flagged as a jump', () {
      // 1.6 mg/dL/min -- well under the physiologic ceiling.
      final cgm = trace(DateTime(2026, 7, 4, 8), [100, 108, 116, 124, 132]);
      final out = const CgmFaultDetector().detect(cgm);
      expect(out.where((e) => e.kind == CgmFaultKind.jump), isEmpty);
    });

    test('flags a stuck run spanning the minimum flatline window', () {
      // 25 minutes of bit-identical readings -- a live glucose trace always has
      // at least minor sensor noise, this is a stuck sensor.
      final cgm = trace(DateTime(2026, 7, 4, 8), [120, 120, 120, 120, 120, 120]);
      final out = const CgmFaultDetector().detect(cgm);
      expect(out.any((e) => e.kind == CgmFaultKind.flatline), isTrue);
    });

    test('normal glucose noise across the same span is not flagged as flatline',
        () {
      final cgm = trace(DateTime(2026, 7, 4, 8), [120, 122, 119, 123, 121, 118]);
      final out = const CgmFaultDetector().detect(cgm);
      expect(out.where((e) => e.kind == CgmFaultKind.flatline), isEmpty);
    });

    test(
        'a run that stays flat for HOURS is only flagged for its first '
        '~flatlineWindow, not its entire span -- excluding an unbounded amount '
        'of training data for one stuck-sensor episode would be its own bug',
        () {
      final start = DateTime(2026, 7, 4, 0);
      // 4 hours of bit-identical readings (48 samples @ 5-min).
      final cgm = trace(start, List.filled(48, 120.0));
      final out = const CgmFaultDetector().detect(cgm);
      final flatlines = out.where((e) => e.kind == CgmFaultKind.flatline);
      expect(flatlines, hasLength(1));
      final span = flatlines.first.end.difference(flatlines.first.start);
      expect(span, lessThan(const Duration(hours: 1)),
          reason: 'the whole 4h run must not be excluded from training');
    });

    test('flags the readings bracketing a dropout gap', () {
      final start = DateTime(2026, 7, 4, 8);
      final cgm = [
        CgmSample(time: start, mgdl: 120),
        CgmSample(
            time: start.add(const Duration(minutes: 25)), mgdl: 118), // gap
      ];
      final out = const CgmFaultDetector().detect(cgm);
      final edge =
          out.where((e) => e.kind == CgmFaultKind.dropoutEdge).toList();
      expect(edge, isNotEmpty);
      expect(edge.first.covers(start), isTrue);
      expect(edge.first.covers(start.add(const Duration(minutes: 25))), isTrue);
    });

    test('a normal ~5-min cadence gap is not flagged as a dropout', () {
      final cgm = trace(DateTime(2026, 7, 4, 8), [120, 121, 122]);
      final out = const CgmFaultDetector().detect(cgm);
      expect(out.where((e) => e.kind == CgmFaultKind.dropoutEdge), isEmpty);
    });

    test('degenerate CGM input -> no throw, empty result', () {
      for (final cgm in [
        const <CgmSample>[],
        trace(DateTime(2026, 7, 4, 8), [120]),
      ]) {
        expect(() => const CgmFaultDetector().detect(cgm), returnsNormally);
        expect(const CgmFaultDetector().detect(cgm), isEmpty);
      }
    });
  });

  // All four AttributionKernel consumers over degenerate CGM input
  // (empty, single-sample, all-gap) in one table-driven sweep. MealDetector is the
  // only one with a pre-loop `.first`/`.last`-style access outside the kernel's own
  // `for (i = 1; ...)` loop (which is itself empty/single-sample-safe by
  // construction) -- CompressionLowDetector, Autotune and the TOD analyzer were
  // already safe, but nothing pinned that before this sweep either.
  group('degenerate CGM input across all 4 kernel consumers', () {
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
