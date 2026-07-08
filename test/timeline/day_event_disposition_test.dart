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

    test('an ignored unannounced rise carries the suggested carbs into the '
        'annotation', () {
      final e = DayEvent(
        id: '3',
        type: DayEventType.detectedMeal,
        time: DateTime(2026, 7, 4, 18),
        title: 'Unannounced rise',
        detail: '',
        suggestedCarbsGrams: 45,
        disposition: ModelDisposition.ignore,
        ignoreReason: IgnoreReason.missedCarbs,
      );
      final a = e.toAnnotation()!;
      expect(a.kind, AnnotationKind.missedCarbs);
      expect(a.carbsGrams, 45);
    });

    test('missedCarbs with no suggestion defaults the annotation carbs to 0', () {
      final e = DayEvent(
        id: '4',
        type: DayEventType.detectedMeal,
        time: DateTime(2026, 7, 4, 18),
        title: 'Unannounced rise',
        detail: '',
        disposition: ModelDisposition.ignore,
        ignoreReason: IgnoreReason.missedCarbs,
      );
      expect(e.toAnnotation()!.carbsGrams, 0);
    });

    test('a non-missedCarbs ignore never carries carbs, even if suggested', () {
      final e = DayEvent(
        id: '5',
        type: DayEventType.high,
        time: DateTime(2026, 7, 4, 18),
        title: 'High',
        detail: '',
        suggestedCarbsGrams: 30, // irrelevant for this reason
        disposition: ModelDisposition.ignore,
        ignoreReason: IgnoreReason.illness,
      );
      expect(e.toAnnotation()!.carbsGrams, 0);
    });

    test('toAnnotation uses the explicit endTime when given', () {
      final start = DateTime(2026, 7, 4, 3);
      final end = DateTime(2026, 7, 4, 3, 45);
      final e = DayEvent(
        id: '6',
        type: DayEventType.compressionLow,
        time: start,
        endTime: end,
        title: 'Compression low',
        detail: '',
        disposition: ModelDisposition.ignore,
        ignoreReason: IgnoreReason.compressionLow,
      );
      expect(e.toAnnotation()!.end, end);
    });

    test('toAnnotation falls back to a 30-minute window when endTime is absent', () {
      final start = DateTime(2026, 7, 4, 3);
      final e = DayEvent(
        id: '7',
        type: DayEventType.compressionLow,
        time: start,
        title: 'Compression low',
        detail: '',
        disposition: ModelDisposition.ignore,
        ignoreReason: IgnoreReason.compressionLow,
      );
      expect(e.toAnnotation()!.end, start.add(const Duration(minutes: 30)));
    });

    test('ignore with no reason set writes no annotation', () {
      final e = DayEvent(
        id: '8',
        type: DayEventType.compressionLow,
        time: DateTime(2026, 7, 4, 3),
        title: 'Compression low',
        detail: '',
        disposition: ModelDisposition.ignore,
      );
      expect(e.toAnnotation(), isNull);
    });
  });

  group('DayEvent.copyWith', () {
    final base = DayEvent(
      id: '9',
      type: DayEventType.high,
      time: DateTime(2026, 7, 4, 9),
      endTime: DateTime(2026, 7, 4, 9, 30),
      title: 'High',
      detail: 'detail',
      mgdl: 210,
      suggestedCarbsGrams: 12,
      explainable: true,
    );

    test('overrides disposition and ignoreReason, keeps everything else', () {
      final copy = base.copyWith(
        disposition: ModelDisposition.ignore,
        ignoreReason: IgnoreReason.illness,
      );
      expect(copy.disposition, ModelDisposition.ignore);
      expect(copy.ignoreReason, IgnoreReason.illness);
      expect(copy.id, base.id);
      expect(copy.type, base.type);
      expect(copy.time, base.time);
      expect(copy.endTime, base.endTime);
      expect(copy.title, base.title);
      expect(copy.detail, base.detail);
      expect(copy.mgdl, base.mgdl);
      expect(copy.suggestedCarbsGrams, base.suggestedCarbsGrams);
      expect(copy.explainable, base.explainable);
    });

    test('omitted fields fall back to the original values', () {
      final copy = base.copyWith();
      expect(copy.disposition, base.disposition);
      expect(copy.ignoreReason, base.ignoreReason);
    });
  });

  group('DayEventType.label / emoji', () {
    test('every type has a distinct, non-empty label and emoji', () {
      final labels = <String>{};
      final emojis = <String>{};
      for (final t in DayEventType.values) {
        expect(t.label, isNotEmpty, reason: t.name);
        expect(t.emoji, isNotEmpty, reason: t.name);
        labels.add(t.label);
        emojis.add(t.emoji);
      }
      expect(labels, hasLength(DayEventType.values.length));
      expect(emojis, hasLength(DayEventType.values.length));
    });
  });

  group('IgnoreReason.label / annotationKind', () {
    test('every reason has a distinct, non-empty label', () {
      final labels = IgnoreReason.values.map((r) => r.label).toSet();
      expect(labels, hasLength(IgnoreReason.values.length));
      for (final r in IgnoreReason.values) {
        expect(r.label, isNotEmpty, reason: r.name);
      }
    });

    test('every reason maps to its matching AnnotationKind', () {
      expect(IgnoreReason.compressionLow.annotationKind,
          AnnotationKind.compressionLow);
      expect(
          IgnoreReason.sensorWarmup.annotationKind, AnnotationKind.sensorWarmup);
      expect(IgnoreReason.siteFailure.annotationKind, AnnotationKind.siteFailure);
      expect(IgnoreReason.illness.annotationKind, AnnotationKind.illness);
      expect(
          IgnoreReason.missedCarbs.annotationKind, AnnotationKind.missedCarbs);
      expect(IgnoreReason.other.annotationKind, AnnotationKind.other);
    });
  });

  group('relevantReasons coverage for every type', () {
    test('every DayEventType has at least one relevant reason, and "other" is '
        'always offered', () {
      for (final t in DayEventType.values) {
        expect(t.relevantReasons, isNotEmpty, reason: t.name);
        expect(t.relevantReasons, contains(IgnoreReason.other), reason: t.name);
      }
    });

    test('a low offers the same CGM-artefact reasons as a compression low', () {
      expect(DayEventType.low.relevantReasons,
          DayEventType.compressionLow.relevantReasons);
    });

    test('device/exercise/prediction events fall through to just "other"', () {
      for (final t in [
        DayEventType.exercise,
        DayEventType.sensorChange,
        DayEventType.siteChange,
        DayEventType.prediction,
      ]) {
        expect(t.relevantReasons, [IgnoreReason.other], reason: t.name);
      }
    });
  });
}
