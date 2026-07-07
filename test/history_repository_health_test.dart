import 'package:bgdude/data/database.dart';
import 'package:bgdude/data/health_sync.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/logging/app_log.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-207: one health-sample row with empty/non-JSON `meta` must not abort the
/// whole range read — every other row's context (context builder, reports,
/// training features) would silently vanish along with it.
///
/// TASK-268 extends the same class of guard to annotations() (out-of-range
/// AnnotationKind index), below.
void main() {
  setUp(() => appLog.clear());

  test('a row with corrupt meta is skipped; other rows are still returned',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftHistoryRepository(db);
    final t = DateTime(2026, 7, 8, 8);

    await repo.saveHealth([
      HealthSample(time: t, type: HealthMetric.steps, value: 5000, meta: const {}),
      HealthSample(
          time: t.add(const Duration(hours: 2)),
          type: HealthMetric.restingHr,
          value: 60,
          meta: const {}),
    ]);
    // Insert a THIRD row directly with malformed meta, bypassing saveHealth's own
    // always-valid jsonEncode -- simulating a genuinely corrupt/truncated write.
    await db.into(db.healthSamples).insert(HealthSamplesCompanion.insert(
          time: t.add(const Duration(hours: 1)),
          type: HealthMetric.hrvRmssd.dbString,
          value: 42,
          meta: const Value('not-json{'),
        ));

    final samples = await repo.health(
        t.subtract(const Duration(hours: 1)), t.add(const Duration(hours: 3)));

    // The two good rows survive; the corrupt one is silently skipped (or would
    // default meta to {} -- either way nothing throws and nothing else is lost).
    expect(samples, hasLength(3));
    final byType = {for (final s in samples) s.type: s};
    expect(byType[HealthMetric.steps]!.value, 5000);
    expect(byType[HealthMetric.restingHr]!.value, 60);
    expect(byType[HealthMetric.hrvRmssd]!.value, 42);
    expect(byType[HealthMetric.hrvRmssd]!.meta, isEmpty,
        reason: 'corrupt meta defaults to {} rather than throwing');
    expect(
        appLog.entries.any((e) =>
            e.level == LogLevel.error &&
            e.tag == 'persistence' &&
            e.message.contains('corrupt health-sample meta')),
        isTrue,
        reason: 'the corruption must be loud in the log, not just silently defaulted');
  });

  test('a completely empty-string meta also defaults to {} rather than throwing',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = DriftHistoryRepository(db);
    final t = DateTime(2026, 7, 8, 8);

    await db.into(db.healthSamples).insert(HealthSamplesCompanion.insert(
          time: t,
          type: HealthMetric.sleepHours.dbString,
          value: 7.5,
          meta: const Value(''),
        ));

    final samples = await repo.health(
        t.subtract(const Duration(hours: 1)), t.add(const Duration(hours: 1)));
    expect(samples, hasLength(1));
    expect(samples.single.meta, isEmpty);
    expect(samples.single.value, 7.5);
  });

  group('annotations (TASK-268)', () {
    test('an out-of-range kind index is skipped; other annotations survive',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftHistoryRepository(db);
      final t = DateTime(2026, 7, 8, 8);

      await repo.saveAnnotation(Annotation(
        id: 'a1',
        kind: AnnotationKind.illness,
        start: t,
        end: t.add(const Duration(hours: 1)),
      ));
      await repo.saveAnnotation(Annotation(
        id: 'a2',
        kind: AnnotationKind.missedCarbs,
        start: t.add(const Duration(hours: 2)),
        end: t.add(const Duration(hours: 3)),
        carbsGrams: 20,
      ));
      // Insert a THIRD row directly with a kind index past the end of
      // AnnotationKind.values -- simulating an enum removed/reordered since this
      // row was written (the exact TASK-207 class of drift), or plain corruption.
      await db.into(db.annotations).insert(AnnotationsCompanion.insert(
            id: 'a3',
            kind: AnnotationKind.values.length + 5,
            start: t.add(const Duration(hours: 4)),
            end: t.add(const Duration(hours: 5)),
          ));

      final result = await repo.annotations(
          t.subtract(const Duration(hours: 1)), t.add(const Duration(hours: 6)));

      // The two good rows survive; the corrupt one is dropped, not the whole read.
      expect(result.map((a) => a.id), containsAll(['a1', 'a2']));
      expect(result, hasLength(2));
      expect(
          appLog.entries.any((e) =>
              e.level == LogLevel.error &&
              e.tag == 'persistence' &&
              e.message.contains('a3')),
          isTrue,
          reason: 'the drift must be loud in the log, not just silently dropped');
    });
  });
}
