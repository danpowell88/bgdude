import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/feedback/confirmation_service.dart';
import 'package:bgdude/feedback/pending_confirmation.dart';
import 'package:bgdude/insights/illness_mode.dart';
import 'package:flutter_test/flutter_test.dart';

/// A steady unexplained rise from noon (roc ~2 mg/dL/min), no insulin, no carbs → an
/// unannounced-meal candidate.
List<CgmSample> _risingMeal(DateTime start) => [
      for (var i = 0; i <= 6; i++)
        CgmSample(
            time: start.add(Duration(minutes: 5 * i)),
            mgdl: 100 + 10.0 * i),
    ];

/// A sharp overnight dip + fast rebound → a compression-low candidate.
List<CgmSample> _compression(DateTime t) => [
      CgmSample(time: t, mgdl: 120),
      CgmSample(time: t.add(const Duration(minutes: 5)), mgdl: 118),
      CgmSample(time: t.add(const Duration(minutes: 10)), mgdl: 100), // pre
      CgmSample(time: t.add(const Duration(minutes: 15)), mgdl: 82), // nadir
      CgmSample(time: t.add(const Duration(minutes: 20)), mgdl: 100), // rebound
      CgmSample(time: t.add(const Duration(minutes: 25)), mgdl: 108),
    ];

void main() {
  final settings = TherapySettings.placeholder();
  const svc = ConfirmationService();

  group('ConfirmationService.scan', () {
    final noon = DateTime(2026, 7, 4, 12);

    test('surfaces an unannounced meal', () {
      final items = svc.scan(
        now: noon.add(const Duration(hours: 1)),
        cgm: _risingMeal(noon),
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: settings,
        annotations: const [],
        decidedIds: const {},
      );
      final meal = items.where((i) => i.type == ConfirmationType.unannouncedMeal);
      expect(meal, isNotEmpty);
      expect(meal.first.carbsGrams, greaterThan(0));
      expect(meal.first.suggestedKind, AnnotationKind.missedCarbs);
    });

    test('skips a meal that was announced (carbs logged nearby)', () {
      final items = svc.scan(
        now: noon.add(const Duration(hours: 1)),
        cgm: _risingMeal(noon),
        boluses: const [],
        basal: const [],
        carbs: [CarbEntry(time: noon.add(const Duration(minutes: 2)), grams: 40)],
        settings: settings,
        annotations: const [],
        decidedIds: const {},
      );
      expect(items.where((i) => i.type == ConfirmationType.unannouncedMeal),
          isEmpty);
    });

    test('excludes items already decided', () {
      final first = svc.scan(
        now: noon.add(const Duration(hours: 1)),
        cgm: _risingMeal(noon),
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: settings,
        annotations: const [],
        decidedIds: const {},
      );
      final id = first.first.id;
      final second = svc.scan(
        now: noon.add(const Duration(hours: 1)),
        cgm: _risingMeal(noon),
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: settings,
        annotations: const [],
        decidedIds: {id},
      );
      expect(second.any((i) => i.id == id), isFalse);
    });

    test('excludes windows already annotated', () {
      final items = svc.scan(
        now: noon.add(const Duration(hours: 1)),
        cgm: _risingMeal(noon),
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: settings,
        annotations: [
          Annotation(
            id: 'x',
            kind: AnnotationKind.missedCarbs,
            start: noon.subtract(const Duration(minutes: 10)),
            end: noon.add(const Duration(minutes: 40)),
          ),
        ],
        decidedIds: const {},
      );
      expect(items.where((i) => i.type == ConfirmationType.unannouncedMeal),
          isEmpty);
    });

    test('detects a compression low overnight', () {
      final t = DateTime(2026, 7, 4, 2);
      final items = svc.scan(
        now: t.add(const Duration(hours: 1)),
        cgm: _compression(t),
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: settings,
        annotations: const [],
        decidedIds: const {},
      );
      expect(items.any((i) => i.type == ConfirmationType.compressionLow), isTrue);
    });

    test('surfaces illness with a day-stable id', () {
      const illness = IllnessSuggestion(
          score: 0.8, reasons: ['glucose ~25% above baseline'],
          suggestActivation: true);
      final items = svc.scan(
        now: noon,
        cgm: const [],
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: settings,
        annotations: const [],
        decidedIds: const {},
        illness: illness,
      );
      final ill = items.where((i) => i.type == ConfirmationType.illness);
      expect(ill, isNotEmpty);
      // Same day → same id regardless of scan time-of-day.
      final later = svc.scan(
        now: DateTime(2026, 7, 4, 20),
        cgm: const [],
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: settings,
        annotations: const [],
        decidedIds: const {},
        illness: illness,
      );
      expect(later.first.id, ill.first.id);
    });
  });

  group('ConfirmationDecisionStore', () {
    setUp(KvStore.useMemory);

    test('records and reloads decisions', () async {
      await ConfirmationDecisionStore.record(
          'unannouncedMeal:42', ConfirmationDecision.confirmed,
          at: DateTime(2026, 7, 4, 12));
      await ConfirmationDecisionStore.record(
          'compressionLow:7', ConfirmationDecision.dismissed,
          at: DateTime(2026, 7, 4, 13));
      final decided = await ConfirmationDecisionStore.load();
      expect(decided['unannouncedMeal:42'], ConfirmationDecision.confirmed);
      expect(decided['compressionLow:7'], ConfirmationDecision.dismissed);
    });
  });

  test('PendingConfirmation id is stable within a 30-minute bucket', () {
    final a = PendingConfirmation(
      type: ConfirmationType.unannouncedMeal,
      start: DateTime(2026, 7, 4, 12, 5),
      end: DateTime(2026, 7, 4, 12, 35),
      title: 't',
      detail: 'd',
      confidence: 0.5,
    );
    final b = PendingConfirmation(
      type: ConfirmationType.unannouncedMeal,
      start: DateTime(2026, 7, 4, 12, 20),
      end: DateTime(2026, 7, 4, 12, 50),
      title: 't',
      detail: 'd',
      confidence: 0.5,
    );
    expect(a.id, b.id); // same 30-min bucket
  });
}
