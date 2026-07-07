import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/ml/sensitivity_model.dart';
import 'package:bgdude/ml/sensitivity_training.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contextual features shared by every synthetic day; only [sleepHours] varies so
/// the model can attribute label variance to sleep.
ContextFeatures _context(double sleepHours) => ContextFeatures(
      sleepHours: sleepHours,
      sleepEfficiency: 0.9,
      overnightHrvRmssd: 50,
      restingHr: 60,
      priorDayExerciseLoad: 0.0,
      menstrualLutealPhase: 0.0,
      illnessFlag: 0.0,
      baselineHrv: 50,
      baselineRestingHr: 60,
    );

/// Synthesize one day.
///
/// [resistant] days let glucose *rise* despite active insulin (insulin
/// underperformed => higher Autotune multiplier); non-resistant days let glucose
/// fall faster than the modelled insulin effect (insulin overperformed => lower
/// multiplier). Insulin is kept small so the modelled drop doesn't swamp the
/// synthetic observed change. [carbFree] controls whether the day has enough
/// carb-free observation time to be usable.
SensitivityDayInput _day({
  required DateTime day,
  required double sleepHours,
  required bool resistant,
  bool carbFree = true,
}) {
  final settings = TherapySettings.placeholder();
  final bolusTime = DateTime(day.year, day.month, day.day, 6, 0);
  final boluses = [BolusEvent(time: bolusTime, units: 0.6)];
  final basal = [
    BasalSegment(
      start: DateTime(day.year, day.month, day.day),
      end: DateTime(day.year, day.month, day.day, 10, 0),
      unitsPerHour: 0.2,
    ),
  ];

  final windowStart = DateTime(day.year, day.month, day.day, 6, 30);
  // 36 steps * 5 min = 180 min carb-free (>= floor); 3 steps ~ 15 min (< floor).
  final steps = carbFree ? 36 : 3;
  final cgm = <CgmSample>[];
  var g = resistant ? 120.0 : 220.0;
  for (var i = 0; i <= steps; i++) {
    cgm.add(CgmSample(
      time: windowStart.add(Duration(minutes: 5 * i)),
      mgdl: g,
    ));
    // Rising under insulin => resistant; steep fall => sensitive.
    g += resistant ? 1.0 : -4.0;
  }

  return SensitivityDayInput(
    day: day,
    cgm: cgm,
    boluses: boluses,
    basal: basal,
    carbs: const [],
    context: _context(sleepHours),
    settings: settings,
  );
}

/// [count] usable days, alternating short-sleep/resistant and long-sleep/sensitive.
List<SensitivityDayInput> _usableDays(int count) => [
      for (var i = 0; i < count; i++)
        _day(
          day: DateTime(2026, 6, 1).add(Duration(days: i)),
          sleepHours: i.isEven ? 4.5 : 8.0,
          resistant: i.isEven,
        ),
    ];

void main() {
  const service = SensitivityTrainingService();

  group('buildExamples', () {
    test('skips days below the carb-free-time floor', () {
      final usable = _usableDays(24);
      final shorts = [
        for (var i = 0; i < 3; i++)
          _day(
            day: DateTime(2026, 8, 1).add(Duration(days: i)),
            sleepHours: 5.0,
            resistant: true,
            carbFree: false,
          ),
      ];

      // The short days on their own produce no examples.
      expect(service.buildExamples(shorts), isEmpty);

      // Mixed in, only the usable days survive.
      expect(service.buildExamples([...usable, ...shorts]).length, 24);
    });

    test('weights each example by day confidence in [0.1, 1.0]', () {
      final examples = service.buildExamples(_usableDays(4));
      expect(examples, isNotEmpty);
      for (final e in examples) {
        expect(e.weight, greaterThanOrEqualTo(0.1));
        expect(e.weight, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('train', () {
    test('returns a trained model from >= minDays usable examples', () {
      final model = service.train(_usableDays(24));
      expect(model, isNotNull);
      expect(model!.isTrained, isTrue);
    });

    test('returns null below minDays usable examples', () {
      expect(service.train(_usableDays(10)), isNull);
    });

    test('CV picks a lambda from the grid and measures real skill', () {
      final model = service.train(_usableDays(24))!;
      // Sleep alternates in lockstep with the label, so LOO-CV skill is high.
      expect(model.cvSkill, isNotNull);
      expect(model.cvSkill!, greaterThan(0.5));
      expect(SensitivityModel.lambdaGrid, contains(model.chosenLambda));
    });

    test('trained model responds to a short-sleep context', () {
      final model = service.train(_usableDays(24))!;

      final shortSleep = model.contextFor(_context(4.5), trainingDays: 24);
      final goodSleep = model.contextFor(_context(8.0), trainingDays: 24);

      // Model is trusted (non-neutral) and surfaces the driver.
      expect(shortSleep.confidence, greaterThan(0));
      expect(shortSleep.reasons, contains('short sleep'));

      // Learned direction: short sleep => more resistant than good sleep.
      expect(
        shortSleep.resistanceMultiplier,
        greaterThan(goodSleep.resistanceMultiplier),
      );
    });
  });

  group('SensitivityModel guardrails (TASK-21)', () {
    test('a coefficient confounded to the wrong physiological sign is clamped to 0',
        () {
      // Illness is deliberately confounded with long sleep here (co-occurs on the
      // same days), so an unconstrained fit would want to give it the SAME
      // (negative/sensitising) sign as sleep's real effect — the opposite of the
      // expected direction (illness should only ever raise resistance).
      final examples = [
        for (var i = 0; i < 12; i++)
          SensitivityExample(
            features: ContextFeatures(
              sleepHours: i.isEven ? 4.5 : 8.0,
              sleepEfficiency: 0.9,
              overnightHrvRmssd: 50,
              restingHr: 60,
              priorDayExerciseLoad: 0.0,
              menstrualLutealPhase: 0.0,
              illnessFlag: i.isEven ? 0.0 : 1.0,
              baselineHrv: 50,
              baselineRestingHr: 60,
            ),
            sensitivityDeviation: i.isEven ? 1.3 : 0.8,
          ),
      ];

      final model = SensitivityModel(minExamples: 8)..train(examples);
      expect(model.isTrained, isTrue,
          reason: 'sleep alone gives it plenty of real signal to beat the heuristic');
      const illnessIndex = 6; // ContextFeatures.featureNames order
      expect(model.model!.weights[illnessIndex], 0.0,
          reason: 'illness fit the wrong (sensitising) sign here and must be clamped');
    });

    test('the heuristic wins (model declined) when a linear fit cannot match it',
        () {
      // Labels are exactly the heuristic's own step-function output across sleep
      // durations spanning its thresholds — a straight-line ridge fit structurally
      // can't reproduce three distinct plateaus, so it can't beat the heuristic's
      // ~zero error against its own labels.
      final hours = [4.0, 4.5, 4.9, 5.0, 5.4, 5.9, 6.0, 6.4, 7.0, 7.5, 8.0, 9.0];
      final examples = [
        for (final h in hours)
          SensitivityExample(
            features: _context(h),
            sensitivityDeviation:
                heuristicSensitivity(_context(h)).resistanceMultiplier,
          ),
      ];

      final model = SensitivityModel(minExamples: 8)..train(examples);
      expect(model.isTrained, isFalse);
      expect(model.beatsHeuristic, isFalse);
      expect(model.model, isNull);
    });

    test(
        'a fit that passes the gate unconstrained but loses after sign-constraining '
        'is NOT adopted (TASK-244)', () {
      // label = 1.0 + heuristic's OWN sleep bump (so the heuristic is a genuinely
      // decent baseline here) + a small, WRONGLY-signed spo2 offset (spo2 delta
      // should REDUCE resistance per _expectedSign, but here it's rigged to
      // correlate the opposite way). An unconstrained ridge fit exploits spo2 to
      // fit near-perfectly and easily beats the heuristic; but spo2's wrong-signed
      // coefficient gets zeroed by _signConstrained before the model ships, leaving
      // only a tiny, genuinely-weak sleep coefficient that does worse than the
      // heuristic's own tuned thresholds. The adoption gate must score THIS
      // (deployed) model, not the unconstrained one that only exists during fitting.
      final rows = <(double sleep, double spo2Delta, double label)>[];
      for (final spo2Delta in [-3.0, 3.0]) {
        final offset = spo2Delta < 0 ? -0.05 : 0.05; // wrong sign vs expected -1
        for (final sleep in [4.0, 4.3, 4.6, 4.9]) {
          rows.add((sleep, spo2Delta, 1.0 + 0.20 + offset)); // < 5h bucket
        }
        for (final sleep in [5.1, 5.4, 5.7, 5.9]) {
          rows.add((sleep, spo2Delta, 1.0 + 0.12 + offset)); // < 6h bucket
        }
        for (final sleep in [6.5, 7.0, 7.5, 8.0]) {
          rows.add((sleep, spo2Delta, 1.0 + offset)); // >= 6h bucket
        }
      }
      final examples = [
        for (final r in rows)
          SensitivityExample(
            features: ContextFeatures(
              sleepHours: r.$1,
              sleepEfficiency: 0.9,
              overnightHrvRmssd: 50,
              restingHr: 60,
              priorDayExerciseLoad: 0.0,
              menstrualLutealPhase: 0.0,
              illnessFlag: 0.0,
              baselineHrv: 50,
              baselineRestingHr: 60,
              spo2: 97 + r.$2,
              baselineSpo2: 97,
            ),
            sensitivityDeviation: r.$3,
          ),
      ];

      final model = SensitivityModel(minExamples: 8)..train(examples);

      // The correctness claim this test exists to pin: verified by temporarily
      // reverting _looMse to fit unconstrained (matching this exact scenario)
      // during development, which showed isTrained/beatsHeuristic both true with
      // cvSkill ~0.89 -- i.e. this data DOES pass the gate if scored unconstrained.
      // With the real (constrained) _looMse, it must not be adopted.
      expect(model.isTrained, isFalse);
      expect(model.beatsHeuristic, isFalse);
      expect(model.model, isNull);
      expect(model.cvSkill, isNull);
    });
  });

  group('trainTimeOfDay', () {
    test('returns a profile from >= analyzer minDays of history', () {
      final profile = service.trainTimeOfDay(_usableDays(24));
      expect(profile, isNotNull);
      expect(profile!.trainedDays, 24);
    });

    test('returns null below the analyzer minDays', () {
      expect(service.trainTimeOfDay(_usableDays(10)), isNull);
    });
  });
}
