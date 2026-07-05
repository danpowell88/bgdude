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
