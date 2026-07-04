import 'package:bgdude/analytics/context_builder.dart';
import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/units.dart';
import 'package:bgdude/data/health_sync.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/dev/sim_data.dart';
import 'package:bgdude/insights/alert_monitor.dart';
import 'package:bgdude/logging/device_changes.dart';
import 'package:bgdude/meals/meal_library.dart';
import 'package:bgdude/meals/meal_log.dart';
import 'package:bgdude/meals/meal_outcome_service.dart';
import 'package:bgdude/ml/accuracy_report.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:bgdude/ml/forecaster_training.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryHistoryRepository', () {
    test('saves and queries CGM, dedups by time, reconciles predictions', () async {
      final repo = InMemoryHistoryRepository();
      final t0 = DateTime(2026, 7, 4, 8);
      final samples = [
        for (var i = 0; i < 24; i++)
          CgmSample(time: t0.add(Duration(minutes: 5 * i)), mgdl: 120 + i.toDouble()),
      ];
      await repo.saveCgm(samples);
      await repo.saveCgm(samples); // dedup
      final got = await repo.cgm(t0, t0.add(const Duration(hours: 2)));
      expect(got.length, 24);

      // A prediction whose target has passed gets an actual filled in.
      await repo.savePrediction(StoredPrediction(
        madeAt: t0,
        horizonMinutes: 30,
        predictedMgdl: 140,
        lowerMgdl: 120,
        upperMgdl: 160,
        modelId: 'deterministic',
      ));
      final updated = await repo.reconcilePredictions(t0.add(const Duration(hours: 3)));
      expect(updated, 1);
      final preds = await repo.predictions(t0.subtract(const Duration(hours: 1)),
          t0.add(const Duration(hours: 1)));
      expect(preds.single.actualMgdl, isNotNull);
    });
  });

  group('ContextBuilder', () {
    test('builds features with relative baselines from health samples', () {
      final now = DateTime(2026, 7, 4, 7);
      final today = [
        HealthSample(time: now, type: 'sleepHours', value: 5.5),
        HealthSample(time: now, type: 'sleepEfficiency', value: 0.85),
        HealthSample(time: now, type: 'hrvRmssd', value: 40),
        HealthSample(time: now, type: 'restingHr', value: 62),
        HealthSample(time: now, type: 'exercise', value: 45),
      ];
      final baseline = [
        for (var d = 1; d < 14; d++) ...[
          HealthSample(
              time: now.subtract(Duration(days: d)), type: 'hrvRmssd', value: 55),
          HealthSample(
              time: now.subtract(Duration(days: d)), type: 'restingHr', value: 56),
        ],
      ];
      final f = ContextBuilder.build(today: today, baseline: baseline)!;
      expect(f.sleepHours, 5.5);
      expect(f.baselineHrv, 55);
      expect(f.overnightHrvRmssd, 40);
      expect(f.priorDayExerciseLoad, closeTo(0.5, 0.01));
    });

    test('returns null with no data', () {
      expect(ContextBuilder.build(today: const [], baseline: const []), isNull);
    });
  });

  group('AlertMonitor', () {
    const monitor = AlertMonitor();
    final now = DateTime(2026, 7, 4, 12);
    List<HorizonForecast> fc(double mgdl) => [
          HorizonForecast(
              horizonMinutes: 30, mgdl: mgdl, lowerMgdl: mgdl - 20, upperMgdl: mgdl + 20),
        ];

    test('fires urgent low then respects cooldown', () {
      final fired = <GlucoseAlertKind, DateTime>{};
      final a = monitor.evaluate(
          forecasts: fc(50), currentMgdl: 110, now: now, lastFired: fired);
      expect(a?.kind, GlucoseAlertKind.urgentLow);
      fired[a!.kind] = now;
      final b = monitor.evaluate(
          forecasts: fc(50),
          currentMgdl: 110,
          now: now.add(const Duration(minutes: 5)),
          lastFired: fired);
      expect(b, isNull); // cooldown
    });

    test('predicted high alerts when rising', () {
      final a = monitor.evaluate(
          forecasts: fc(230), currentMgdl: 150, now: now, lastFired: {});
      expect(a?.kind, GlucoseAlertKind.predictedHigh);
    });

    test('no alert when forecast stays in range', () {
      expect(
          monitor.evaluate(
              forecasts: fc(120), currentMgdl: 110, now: now, lastFired: {}),
          isNull);
    });
  });

  group('DeviceState', () {
    test('tracks age and overdue', () {
      final now = DateTime(2026, 7, 4, 12);
      final s = const DeviceState()
          .withChange(DeviceChange(
              kind: DeviceKind.site,
              changedAt: now.subtract(const Duration(days: 4))));
      expect(s.age(DeviceKind.site, now)!.inDays, 4);
      expect(s.isOverdue(DeviceKind.site, now), isTrue); // >3d life
      expect(s.isOverdue(DeviceKind.sensor, now), isFalse); // never changed
    });
  });

  group('MealOutcomeService', () {
    test('learns matured meals from stored CGM', () async {
      final repo = InMemoryHistoryRepository();
      final eatenAt = DateTime(2026, 7, 4, 12);
      // A rise-then-fall around the meal.
      final cgm = [
        for (var m = -30; m <= 210; m += 5)
          CgmSample(
            time: eatenAt.add(Duration(minutes: m)),
            mgdl: m <= 0
                ? 110
                : (m <= 60 ? 110 + m.toDouble() : (170 - (m - 60) * 0.4)),
          ),
      ];
      await repo.saveCgm(cgm);

      final library = MealLibrary(meals: const [
        SavedMeal(id: 'm', name: 'Pasta', carbsGrams: 60),
      ]);
      final log = [
        MealLogEntry(
            id: '1',
            mealId: 'm',
            eatenAt: eatenAt,
            carbsGrams: 60,
            preBolusMinutes: 10,
            bolusUnits: 6),
      ];
      final res = await const MealOutcomeService().process(
        log: log,
        library: library,
        repo: repo,
        now: eatenAt.add(const Duration(hours: 4)),
      );
      expect(res.learned, hasLength(1));
      expect(res.learned.first.outcome.peakMgdl, greaterThan(140));
      expect(res.updatedLog.first.learned, isTrue);
    });
  });

  group('ForecasterTrainer + accuracy', () {
    test('trains from a simulated day and produces held-out evaluations', () {
      final day = SimulatedDay.generate(now: DateTime(2026, 7, 4, 22), seed: 3);
      final result = ForecasterTrainer(strideSamples: 1).train(
        cgm: day.cgm,
        boluses: day.boluses,
        basal: day.basal,
        carbs: day.carbs,
        settings: day.settings,
        annotations: const [],
        asOf: day.end,
      );
      // One simulated day yields enough (timestep, horizon) pairs to train.
      expect(result, isNotNull);
      expect(result!.model.isTrained, isTrue);
      expect(result.candidateEval.sampleCount, greaterThan(0));
    });

    test('AccuracyAnalyzer scores reconciled predictions per horizon', () {
      final preds = [
        for (var i = 0; i < 20; i++)
          StoredPrediction(
            madeAt: DateTime(2026, 7, 4, 8).add(Duration(minutes: 5 * i)),
            horizonMinutes: 30,
            predictedMgdl: 120 + i.toDouble(),
            lowerMgdl: 100,
            upperMgdl: 140,
            modelId: 'residual',
            actualMgdl: 122 + i.toDouble(),
          ),
      ];
      final report = const AccuracyAnalyzer().analyze(preds);
      expect(report.hasData, isTrue);
      expect(report.byHorizon[30], isNotNull);
      expect(report.byHorizon[30]!.abFraction, 1.0); // within 20%
    });
  });

  test('mmol display sanity', () {
    expect(Mgdl(180).display(GlucoseUnit.mmol), '10.0');
  });
}
