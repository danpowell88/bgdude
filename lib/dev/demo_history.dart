/// Multi-day simulated history for **demo mode**, so every report/insight that reads the
/// history repository over a date range (reports, A1c/GMI, sleep, correlations, model
/// accuracy, events journal, basal suggestions) has something to show without hardware.
///
/// It stitches together ~3 weeks of [SimulatedDay]s and derives matching Health-Connect
/// style samples (sleep, HRV, resting HR, steps, exercise), a few confirmed-event
/// annotations, and scored predictions. Poorer-sleep days are nudged to run higher so the
/// correlation report surfaces a real (simulated) sleep↔glucose association.
///
/// This never touches the persistent database — demo mode swaps in a fresh in-memory
/// repository seeded from here (see `demoHistoryRepositoryProvider`).
library;

import '../core/samples.dart';
import '../data/health_sync.dart';
import '../data/history_repository.dart';
import '../feedback/annotations.dart';
import '../meals/meal_library.dart';
import 'sim_data.dart';

/// A bundle of demo time-series ready to load into a repository via `seed(...)`.
class DemoHistoryBundle {
  const DemoHistoryBundle({
    required this.cgm,
    required this.boluses,
    required this.carbs,
    required this.basal,
    required this.health,
    required this.annotations,
    required this.predictions,
  });

  final List<CgmSample> cgm;
  final List<BolusEvent> boluses;
  final List<CarbEntry> carbs;
  final List<BasalSegment> basal;
  final List<HealthSample> health;
  final List<Annotation> annotations;
  final List<StoredPrediction> predictions;
}

class DemoHistory {
  const DemoHistory._();

  /// Build [days] days of history ending at [now]. Defaults cover the 14-day reports and
  /// GMI trend. CGM is thinned to [cgmStride] (every 3rd 5-min sample → 15-min cadence) to
  /// keep the report builders — which run on the UI isolate — responsive on-device.
  static DemoHistoryBundle build({
    required DateTime now,
    int days = 14,
    int cgmStride = 3,
  }) {
    final cgm = <CgmSample>[];
    final boluses = <BolusEvent>[];
    final carbs = <CarbEntry>[];
    final basal = <BasalSegment>[];
    final health = <HealthSample>[];
    final predictions = <StoredPrediction>[];

    // Generate ONE physiologically-consistent day, then replicate it back across the
    // window with per-day time shifts and a glucose offset. Forward-simulating a full day
    // is the expensive part, so doing it once keeps demo startup snappy.
    final template = SimulatedDay.generate(now: now, seed: 7);

    for (var d = days - 1; d >= 0; d--) {
      final dayEnd = now.subtract(Duration(days: d));
      final date = DateTime(dayEnd.year, dayEnd.month, dayEnd.day);
      final shift = Duration(days: d);

      // Deterministic per-day context so correlations have variance to work with.
      final sleepHours = 5.0 + ((d * 3) % 7) * 0.5; // 5.0–8.0
      final sleepEff = 0.80 + ((d * 5) % 15) / 100.0; // 0.80–0.94
      final hrv = 40.0 + (d * 7) % 25; // 40–64
      final restingHr = 66.0 - (d * 5) % 12; // 55–66
      final steps = 5000.0 + (d * 613) % 7000; // 5k–12k
      final exerciseLoad = ((d * 11) % 10) / 10.0; // 0.0–0.9
      // Poorer sleep worsens control — shift that day's trace up a touch.
      final bgShift = (7.0 - sleepHours) * 10.0;

      final dayCgm = <CgmSample>[
        for (var i = 0; i < template.cgm.length; i += cgmStride)
          CgmSample(
            time: template.cgm[i].time.subtract(shift),
            mgdl: (template.cgm[i].mgdl + bgShift).clamp(45.0, 320.0),
            trend: template.cgm[i].trend,
            compressionLow: template.cgm[i].compressionLow,
          ),
      ];
      cgm.addAll(dayCgm);
      for (final b in template.boluses) {
        boluses.add(BolusEvent(
            time: b.time.subtract(shift),
            units: b.units,
            carbsGrams: b.carbsGrams,
            isAutomatic: b.isAutomatic));
      }
      for (final c in template.carbs) {
        carbs.add(CarbEntry(
            time: c.time.subtract(shift),
            grams: c.grams,
            absorptionMinutes: c.absorptionMinutes));
      }
      for (final s in template.basal) {
        basal.add(BasalSegment(
            start: s.start.subtract(shift),
            end: s.end.subtract(shift),
            unitsPerHour: s.unitsPerHour));
      }

      health
        ..add(HealthSample(
            time: date.add(const Duration(hours: 2)),
            type: HealthMetric.sleepHours,
            value: sleepHours))
        ..add(HealthSample(
            time: date.add(const Duration(hours: 2)),
            type: HealthMetric.sleepEfficiency,
            value: sleepEff))
        ..add(HealthSample(
            time: date.add(const Duration(hours: 2)),
            type: HealthMetric.hrvRmssd,
            value: hrv))
        ..add(HealthSample(
            time: date.add(const Duration(hours: 7)),
            type: HealthMetric.restingHr,
            value: restingHr))
        ..add(HealthSample(
            time: date.add(const Duration(hours: 20)),
            type: HealthMetric.steps,
            value: steps))
        ..add(HealthSample(
            time: date.add(const Duration(hours: 13, minutes: 30)),
            type: HealthMetric.exercise,
            value: exerciseLoad));

      // Scored predictions (known actuals) so the model-accuracy report renders.
      for (final h in const [8, 12, 18]) {
        final madeAt = date.add(Duration(hours: h));
        for (final horizon in const [30, 60, 120]) {
          final target = madeAt.add(Duration(minutes: horizon));
          final actual = _nearestMgdl(dayCgm, target);
          if (actual == null) continue;
          final err = (((d + h + horizon) % 7) - 3) * 4.0; // small, deterministic
          predictions.add(StoredPrediction(
            madeAt: madeAt,
            horizonMinutes: horizon,
            predictedMgdl: (actual + err).clamp(45.0, 320.0),
            lowerMgdl: (actual + err - 25).clamp(40.0, 320.0),
            upperMgdl: (actual + err + 25).clamp(40.0, 400.0),
            modelId: 'demo',
            actualMgdl: actual,
          ));
        }
      }
    }

    // A handful of confirmed events for the journal + training exclusions.
    Annotation ann(String id, AnnotationKind kind, int daysAgo, int hour,
            {int durationMin = 30, double carbsGrams = 0}) {
      final start = now
          .subtract(Duration(days: daysAgo))
          .copyWith(hour: hour, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      return Annotation(
        id: id,
        kind: kind,
        start: start,
        end: start.add(Duration(minutes: durationMin)),
        carbsGrams: carbsGrams,
        note: 'Demo ${kind.label}',
      );
    }

    final annotations = <Annotation>[
      ann('demo-comp-1', AnnotationKind.compressionLow, 2, 3),
      ann('demo-site-1', AnnotationKind.siteFailure, 5, 16, durationMin: 180),
      ann('demo-exercise-1', AnnotationKind.exercise, 3, 18, durationMin: 45),
      ann('demo-missed-1', AnnotationKind.missedCarbs, 4, 12, carbsGrams: 20),
      ann('demo-illness-1', AnnotationKind.illness, 9, 9, durationMin: 600),
    ];

    return DemoHistoryBundle(
      cgm: cgm,
      boluses: boluses,
      carbs: carbs,
      basal: basal,
      health: health,
      annotations: annotations,
      predictions: predictions,
    );
  }

  /// A few saved meals with outcome history (last ~2 weeks) so the meal library and the
  /// Meals report render in demo mode.
  static List<SavedMeal> demoMeals({required DateTime now}) {
    MealOutcome outcome(int daysAgo, int hour,
            {required double bg,
            required double peak,
            required double bolus,
            int pre = 10}) =>
        MealOutcome(
          eatenAt: now
              .subtract(Duration(days: daysAgo))
              .copyWith(hour: hour, minute: 0, second: 0, millisecond: 0, microsecond: 0),
          preBolusMinutes: pre,
          bolusUnits: bolus,
          bgAtMealMgdl: bg,
          peakMgdl: peak,
          peakOffsetMinutes: 75,
          bgAt3hMgdl: bg + 10,
          timeAbove180Minutes: peak > 180 ? 40 : 0,
        );

    return [
      SavedMeal(
        id: 'demo-oats',
        name: 'Porridge & berries',
        emoji: '🥣',
        category: MealCategory.breakfast,
        carbsGrams: 45,
        proteinGrams: 8,
        fatGrams: 6,
        outcomes: [
          outcome(2, 8, bg: 120, peak: 165, bolus: 4.5),
          outcome(6, 8, bg: 110, peak: 150, bolus: 4.5),
          outcome(11, 8, bg: 130, peak: 190, bolus: 4.5, pre: 0),
        ],
      ),
      SavedMeal(
        id: 'demo-pizza',
        name: 'Pizza night',
        emoji: '🍕',
        category: MealCategory.dinner,
        carbsGrams: 75,
        proteinGrams: 30,
        fatGrams: 28,
        fatProteinHeavy: true,
        absorptionMinutes: 240,
        peakOffsetMinutes: 150,
        outcomes: [
          outcome(3, 19, bg: 115, peak: 210, bolus: 7.5),
          outcome(9, 19, bg: 125, peak: 225, bolus: 7.5, pre: 15),
        ],
      ),
      SavedMeal(
        id: 'demo-sandwich',
        name: 'Chicken sandwich',
        emoji: '🥪',
        category: MealCategory.lunch,
        carbsGrams: 55,
        proteinGrams: 25,
        fatGrams: 12,
        outcomes: [
          outcome(1, 12, bg: 105, peak: 160, bolus: 5.5),
          outcome(5, 12, bg: 118, peak: 175, bolus: 5.5),
          outcome(12, 12, bg: 100, peak: 145, bolus: 5.5),
        ],
      ),
    ];
  }

  static double? _nearestMgdl(List<CgmSample> cgm, DateTime t) {
    CgmSample? best;
    var bestDelta = const Duration(days: 999);
    for (final s in cgm) {
      final delta = s.time.difference(t).abs();
      if (delta < bestDelta) {
        best = s;
        bestDelta = delta;
      }
    }
    if (best == null || bestDelta > const Duration(minutes: 10)) return null;
    return best.mgdl;
  }
}
