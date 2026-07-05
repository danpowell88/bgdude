import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/timeline/day_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DayEventType defaults', () {
    test('pump dosing (meal/bolus) is pump-sourced and used by default', () {
      for (final t in [DayEventType.meal, DayEventType.bolus]) {
        expect(t.isPumpSourced, isTrue, reason: t.name);
        expect(t.defaultDisposition, ModelDisposition.use, reason: t.name);
        expect(t.defaultIgnoreReason, isNull);
      }
    });

    test('CGM-derived events are not pump-sourced', () {
      for (final t in [
        DayEventType.high,
        DayEventType.low,
        DayEventType.detectedMeal,
        DayEventType.compressionLow,
      ]) {
        expect(t.isPumpSourced, isFalse, reason: t.name);
      }
    });

    test('compression low is excluded by default with the right reason', () {
      expect(DayEventType.compressionLow.defaultDisposition,
          ModelDisposition.ignore);
      expect(DayEventType.compressionLow.defaultIgnoreReason,
          IgnoreReason.compressionLow);
    });

    test('other CGM events default to use', () {
      expect(DayEventType.high.defaultDisposition, ModelDisposition.use);
      expect(DayEventType.low.defaultDisposition, ModelDisposition.use);
    });
  });

  group('contextual ignore reasons', () {
    test('a compression low is never offered "missed carbs"', () {
      final reasons = DayEventType.compressionLow.relevantReasons;
      expect(reasons, contains(IgnoreReason.compressionLow));
      expect(reasons, isNot(contains(IgnoreReason.missedCarbs)));
    });

    test('an unannounced rise offers missed carbs, not compression low', () {
      final reasons = DayEventType.detectedMeal.relevantReasons;
      expect(reasons, contains(IgnoreReason.missedCarbs));
      expect(reasons, isNot(contains(IgnoreReason.compressionLow)));
    });

    test('a high offers site/illness/missed-carbs', () {
      final reasons = DayEventType.high.relevantReasons;
      expect(reasons, containsAll(<IgnoreReason>[
        IgnoreReason.siteFailure,
        IgnoreReason.illness,
        IgnoreReason.missedCarbs,
      ]));
    });

    test('pump dosing only offers "other" (no CGM-artefact reasons)', () {
      expect(DayEventType.meal.relevantReasons, [IgnoreReason.other]);
      expect(DayEventType.bolus.relevantReasons, [IgnoreReason.other]);
    });
  });

  group('event → annotation', () {
    test('an ignored compression low writes a compression-low annotation', () {
      final e = DayEvent(
        id: '1',
        type: DayEventType.compressionLow,
        time: DateTime(2026, 7, 4, 3),
        title: 'Compression low',
        detail: '',
        disposition: ModelDisposition.ignore,
        ignoreReason: IgnoreReason.compressionLow,
      );
      final a = e.toAnnotation();
      expect(a, isNotNull);
      expect(a!.kind, AnnotationKind.compressionLow);
      expect(a.carbsGrams, 0);
    });

    test('a used pump bolus writes no annotation', () {
      final e = DayEvent(
        id: '2',
        type: DayEventType.bolus,
        time: DateTime(2026, 7, 4, 12),
        title: '3 U bolus',
        detail: '',
      );
      expect(e.disposition, ModelDisposition.use);
      expect(e.toAnnotation(), isNull);
    });
  });
}
