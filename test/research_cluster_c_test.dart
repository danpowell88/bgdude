import 'package:bgdude/data/health_sync.dart';
import 'package:bgdude/insights/post_meal_movement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostMealMovementCoach', () {
    const coach = PostMealMovementCoach();

    test('nudges on a predicted post-meal spike when not already moving', () {
      expect(
        coach.shouldNudge(
          ateWithinWindow: true,
          currentMgdl: 120,
          forecastPeakMgdl: 190,
          recentStepsPerMin: 5,
        ),
        isTrue,
      );
    });

    test('does not nudge if already walking', () {
      expect(
        coach.shouldNudge(
          ateWithinWindow: true,
          currentMgdl: 120,
          forecastPeakMgdl: 190,
          recentStepsPerMin: 80,
        ),
        isFalse,
      );
    });

    test('does not nudge without a recent meal or without a real rise', () {
      expect(
        coach.shouldNudge(
          ateWithinWindow: false,
          currentMgdl: 120,
          forecastPeakMgdl: 190,
          recentStepsPerMin: 0,
        ),
        isFalse,
      );
      expect(
        coach.shouldNudge(
          ateWithinWindow: true,
          currentMgdl: 150,
          forecastPeakMgdl: 158, // only +8, below minRise
          recentStepsPerMin: 0,
        ),
        isFalse,
      );
    });
  });

  group('PostMealMovementAnalyzer', () {
    const analyzer = PostMealMovementAnalyzer();

    test('finds that more steps → smaller spikes (negative r)', () {
      // 8 meals: more post-meal steps paired with smaller excursions.
      final base = DateTime(2026, 7, 4, 8);
      final meals = <({DateTime eatenAt, double excursionMgdl})>[];
      final steps = <HealthSample>[];
      for (var i = 0; i < 8; i++) {
        final eatenAt = base.add(Duration(days: i));
        // excursion falls as i rises; steps rise as i rises.
        meals.add((eatenAt: eatenAt, excursionMgdl: 120.0 - i * 10));
        steps.add(HealthSample(
            time: eatenAt.add(const Duration(minutes: 30)),
            type: HealthMetric.steps,
            value: (i * 300).toDouble()));
      }
      final r = analyzer.analyze(meals: meals, steps: steps);
      expect(r.hasSignal, isTrue);
      expect(r.r, lessThan(0));
      expect(r.message, contains('smaller spikes'));
    });

    test('too few meals → no signal', () {
      final r = analyzer.analyze(
        meals: [
          (eatenAt: DateTime(2026, 7, 4, 8), excursionMgdl: 100),
        ],
        steps: const [],
      );
      expect(r.hasSignal, isFalse);
    });
  });
}
