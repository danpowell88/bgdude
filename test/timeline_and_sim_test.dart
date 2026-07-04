import 'package:bgdude/dev/sim_data.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/state/day_data.dart';
import 'package:bgdude/timeline/day_event.dart';
import 'package:bgdude/timeline/event_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 4, 21);

  group('SimulatedDay', () {
    final day = SimulatedDay.generate(now: now, seed: 7);

    test('produces a full day of 5-min CGM in a physiological range', () {
      expect(day.cgm.length, greaterThan(250)); // ~288 for 24h
      final values = day.cgm.map((s) => s.mgdl);
      expect(values.every((v) => v >= 40 && v <= 330), isTrue);
      // Not flat — meals and insulin move it around.
      final min = values.reduce((a, b) => a < b ? a : b);
      final max = values.reduce((a, b) => a > b ? a : b);
      expect(max - min, greaterThan(40));
    });

    test('seeds meals with matching boluses and a compression low', () {
      expect(day.carbs, hasLength(3));
      expect(day.boluses.length, greaterThanOrEqualTo(3));
      expect(day.cgm.any((s) => s.compressionLow), isTrue);
    });

    test('reports a plausible current IOB', () {
      expect(day.iobNow(), greaterThanOrEqualTo(0));
      expect(day.iobNow(), lessThan(20));
    });
  });

  group('EventBuilder', () {
    final day = SimulatedDay.generate(now: now, seed: 7);
    final dayData = DayData(
      start: day.start,
      end: day.end,
      cgm: day.cgm,
      boluses: day.boluses,
      basal: day.basal,
      carbs: day.carbs,
      settings: day.settings,
      context: day.context,
      isSimulated: true,
    );

    test('surfaces meals and a compression low from the simulated day', () {
      final events = EventBuilder().build(dayData);
      expect(events.any((e) => e.type == DayEventType.meal), isTrue);
      final comp =
          events.where((e) => e.type == DayEventType.compressionLow).toList();
      expect(comp, isNotEmpty);
      // Compression lows default to ignore/compression so training excludes them.
      expect(comp.first.disposition, ModelDisposition.ignore);
      expect(comp.first.ignoreReason, IgnoreReason.compressionLow);
    });

    test('events are time-ordered and explainable where expected', () {
      final events = EventBuilder().build(dayData);
      for (var i = 1; i < events.length; i++) {
        expect(events[i - 1].time.isAfter(events[i].time), isFalse);
      }
      final highsLows = events.where((e) =>
          e.type == DayEventType.high || e.type == DayEventType.low);
      expect(highsLows.every((e) => e.explainable), isTrue);
    });

    test('ignored event yields an exclusion annotation for retraining', () {
      final events = EventBuilder().build(dayData);
      final comp =
          events.firstWhere((e) => e.type == DayEventType.compressionLow);
      final annotation = comp.toAnnotation();
      expect(annotation, isNotNull);
      expect(annotation!.kind.excludesFromTraining, isTrue);
    });
  });
}
