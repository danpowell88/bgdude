import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/insights/alcohol_watch.dart';
import 'package:bgdude/insights/workout_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkoutClassifier', () {
    const c = WorkoutClassifier();
    test('classifies common Health Connect activity types', () {
      expect(c.classify('RUNNING'), WorkoutType.aerobic);
      expect(c.classify('WALKING'), WorkoutType.aerobic);
      expect(c.classify('BIKING'), WorkoutType.aerobic);
      expect(c.classify('SWIMMING'), WorkoutType.aerobic);
      expect(c.classify('STRENGTH_TRAINING'), WorkoutType.resistance);
      expect(c.classify('WEIGHTLIFTING'), WorkoutType.resistance);
      expect(c.classify('HIGH_INTENSITY_INTERVAL_TRAINING'), WorkoutType.mixed);
      expect(c.classify('SomeUnknownApp'), WorkoutType.other);
    });

    test('only aerobic/mixed raise hypo risk', () {
      expect(WorkoutType.aerobic.raisesHypoRisk, isTrue);
      expect(WorkoutType.mixed.raisesHypoRisk, isTrue);
      expect(WorkoutType.resistance.raisesHypoRisk, isFalse);
      expect(WorkoutType.other.raisesHypoRisk, isFalse);
    });
  });

  group('AlcoholWatch', () {
    const watch = AlcoholWatch();
    final drinkAt = DateTime(2026, 7, 4, 21); // 9pm

    Annotation alcohol(DateTime at) => Annotation(
          id: 'a',
          kind: AnnotationKind.alcohol,
          start: at,
          end: at.add(const Duration(hours: 2)),
        );

    test('active overnight and next morning, off after the window', () {
      expect(watch.activeAt([alcohol(drinkAt)], drinkAt.add(const Duration(hours: 3))),
          isTrue); // midnight
      expect(watch.activeAt([alcohol(drinkAt)], drinkAt.add(const Duration(hours: 10))),
          isTrue); // 7am next day
      expect(watch.activeAt([alcohol(drinkAt)], drinkAt.add(const Duration(hours: 16))),
          isFalse); // afternoon — past the 14h window
    });

    test('other annotations do not trigger the watch', () {
      final exercise = Annotation(
        id: 'e',
        kind: AnnotationKind.exercise,
        start: drinkAt,
        end: drinkAt.add(const Duration(hours: 1)),
      );
      expect(watch.activeAt([exercise], drinkAt.add(const Duration(hours: 2))),
          isFalse);
    });

    test('raised threshold is higher than the usual low line', () {
      expect(watch.raisedLowMgdl, greaterThan(70));
    });
  });
}
