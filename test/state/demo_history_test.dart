import 'package:bgdude/data/health_sync.dart';
import 'package:bgdude/dev/demo_history.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 5, 14);

  group('DemoHistory.build', () {
    final b = DemoHistory.build(now: now, days: 21);

    test('covers at least two weeks of CGM', () {
      final earliest =
          b.cgm.map((s) => s.time).reduce((a, c) => a.isBefore(c) ? a : c);
      expect(now.difference(earliest).inDays, greaterThanOrEqualTo(14));
      // ~96 fifteen-minute samples/day (thinned from 5-min) over three weeks.
      expect(b.cgm.length, greaterThan(21 * 50));
    });

    test('has daily sleep + HRV + resting-HR + exercise health samples', () {
      final sleep = b.health.where((h) => h.type == HealthMetric.sleepHours).length;
      expect(sleep, greaterThanOrEqualTo(14));
      expect(b.health.any((h) => h.type == HealthMetric.hrvRmssd), isTrue);
      expect(b.health.any((h) => h.type == HealthMetric.restingHr), isTrue);
      expect(b.health.any((h) => h.type == HealthMetric.exercise), isTrue);
      expect(b.health.any((h) => h.type == HealthMetric.steps), isTrue);
    });

    test('sleep varies across days so correlations have signal', () {
      final sleeps = b.health
          .where((h) => h.type == HealthMetric.sleepHours)
          .map((h) => h.value)
          .toSet();
      expect(sleeps.length, greaterThan(1));
    });

    test('every prediction carries an actual for scoring', () {
      expect(b.predictions, isNotEmpty);
      expect(b.predictions.every((p) => p.actualMgdl != null), isTrue);
    });

    test('has confirmed-event annotations', () {
      expect(b.annotations, isNotEmpty);
    });
  });

  test('demo meals carry outcome history', () {
    final meals = DemoHistory.demoMeals(now: now);
    expect(meals, isNotEmpty);
    expect(meals.every((m) => m.outcomes.isNotEmpty), isTrue);
  });

  test('demo mode swaps in a seeded (non-empty) history repository', () async {
    final container = ProviderContainer(
      overrides: [devModeProvider.overrideWith((ref) => true)],
    );
    addTearDown(container.dispose);

    final repo = container.read(historyRepositoryProvider);
    final all = await repo.cgm(DateTime(2000), DateTime(2100));
    expect(all, isNotEmpty);
    final health = await repo.health(DateTime(2000), DateTime(2100));
    expect(health, isNotEmpty);
  });

  test('every range-based report builds quickly from demo data', () async {
    final container = ProviderContainer(
      overrides: [devModeProvider.overrideWith((ref) => true)],
    );
    addTearDown(container.dispose);

    // Building all seven reports (incl. the one-time demo-repo seed) must stay well under
    // this bound. It guards against the O(range²) IOB / Autotune blow-up that used to make
    // demo reports hang on-device.
    final sw = Stopwatch()..start();
    await container.read(glucoseReportProvider.future);
    await container.read(insulinReportProvider.future);
    await container.read(therapyReportProvider.future);
    await container.read(correlationReportProvider.future);
    await container.read(modelReportProvider.future);
    await container.read(eventsJournalProvider.future);
    final mealsReport = container.read(mealsReportProvider);
    sw.stop();

    expect(mealsReport, isNotNull);
    expect(sw.elapsed, lessThan(const Duration(seconds: 12)),
        reason: 'reports took ${sw.elapsedMilliseconds} ms');
  });
}
