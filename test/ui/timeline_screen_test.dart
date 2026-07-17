import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/timeline/day_event.dart';
import 'package:bgdude/ui/timeline_screen.dart';
import 'package:flutter_test/flutter_test.dart';

// TASK-155 coverage: reasonForAnnotationKind is the mapping that drives
// explainDayEvent's "accepting an explanation with an exclusion kind marks the
// event ignore" behaviour (shared by TimelineEventCard's Explain button and the
// chart event-marker overlays added in TASK-155). It's pure data logic, so it's
// unit-tested directly rather than only reachable via a full navigation flow.
void main() {
  group('reasonForAnnotationKind', () {
    test('maps each exclusion-worthy annotation kind to its IgnoreReason', () {
      expect(reasonForAnnotationKind(AnnotationKind.compressionLow),
          IgnoreReason.compressionLow);
      expect(reasonForAnnotationKind(AnnotationKind.siteFailure),
          IgnoreReason.siteFailure);
      expect(reasonForAnnotationKind(AnnotationKind.sensorWarmup),
          IgnoreReason.sensorWarmup);
      expect(
          reasonForAnnotationKind(AnnotationKind.illness), IgnoreReason.illness);
      expect(reasonForAnnotationKind(AnnotationKind.missedCarbs),
          IgnoreReason.missedCarbs);
    });

    test('kinds with no ignore-worthy counterpart return null', () {
      // Context-only / relabel-only / catch-all kinds should not auto-tag the
      // event ignore -- accepting e.g. an "exercise" or "mood" explanation isn't
      // a training-exclusion signal.
      expect(reasonForAnnotationKind(AnnotationKind.extraCarbs), isNull);
      expect(reasonForAnnotationKind(AnnotationKind.exercise), isNull);
      expect(reasonForAnnotationKind(AnnotationKind.stress), isNull);
      expect(reasonForAnnotationKind(AnnotationKind.mood), isNull);
      expect(reasonForAnnotationKind(AnnotationKind.alcohol), isNull);
      expect(reasonForAnnotationKind(AnnotationKind.other), isNull);
      expect(reasonForAnnotationKind(AnnotationKind.medication), isNull);
    });
  });
}
