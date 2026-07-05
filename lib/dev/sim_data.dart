/// Deterministic-ish simulated day of pump + CGM + context data, for dev mode.
///
/// Physiology is generated with the app's OWN insulin/carb math (`InsulinModel`,
/// `CarbModel`) so the traces are self-consistent with what the predictor and bolus
/// advisor expect — predictions over simulated data look sensible rather than random.
///
/// A day contains: 5-min CGM samples over the last 24h, the boluses/carbs/basal that
/// produced them, and the Health-Connect-style context (sleep, HRV, resting HR, steps).
/// It deliberately seeds a few "teachable" events — a post-lunch exercise dip, a
/// nocturnal compression low, and a dawn-phenomenon rise — so the timeline and the
/// event detectors have something to surface.
library;

import 'dart:math' as math;

import '../analytics/carb_math.dart';
import '../analytics/insulin_math.dart';
import '../analytics/therapy_settings.dart';
import '../core/samples.dart';
import '../ml/sensitivity_model.dart';

class SimulatedDay {
  SimulatedDay({
    required this.start,
    required this.end,
    required this.cgm,
    required this.boluses,
    required this.basal,
    required this.carbs,
    required this.settings,
    required this.context,
  });

  final DateTime start;
  final DateTime end;
  final List<CgmSample> cgm;
  final List<BolusEvent> boluses;
  final List<BasalSegment> basal;
  final List<CarbEntry> carbs;
  final TherapySettings settings;
  final ContextFeatures context;

  CgmSample get latest => cgm.last;

  /// The IOB right now from the simulated boluses/basal (for the live snapshot).
  double iobNow() =>
      const IobCalculator().total(boluses, basal, end).units;

  /// Build a full day ending at [now]. [seed] makes the noise reproducible within a
  /// session; pass a rotating value to vary runs.
  factory SimulatedDay.generate({
    required DateTime now,
    int seed = 7,
    TherapySettings? settings,
  }) {
    final rng = math.Random(seed);
    final s = settings ?? _defaultSettings;
    final start = now.subtract(const Duration(hours: 24));
    final seg = s.segmentAt(now);

    // Anchor meals/boluses to the simulated day's calendar.
    DateTime at(int hour, int minute) {
      var t = DateTime(start.year, start.month, start.day, hour, minute);
      if (t.isBefore(start)) t = t.add(const Duration(days: 1));
      return t;
    }

    final carbs = <CarbEntry>[
      CarbEntry(time: at(7, 40), grams: 45), // breakfast
      CarbEntry(time: at(12, 30), grams: 60), // lunch
      CarbEntry(time: at(18, 45), grams: 75, absorptionMinutes: 240), // dinner (pizza)
    ];
    // Boluses ~10 min before each meal, dosed at the meal's carb ratio.
    final boluses = <BolusEvent>[
      for (final c in carbs)
        BolusEvent(
          time: c.time.subtract(const Duration(minutes: 10)),
          units: c.grams / seg.carbRatio,
          carbsGrams: c.grams,
        ),
      // A small correction mid-afternoon.
      BolusEvent(time: at(15, 20), units: 1.2),
    ];
    final basal = <BasalSegment>[
      BasalSegment(start: start, end: now, unitsPerHour: seg.basalUnitsPerHour),
    ];

    // Forward-simulate BG with the app's physiology, stepping every 5 min.
    const step = 5;
    const iob = IobCalculator();
    const carbModel = CarbModel();
    final csf = carbSensitivityFactor(isf: seg.isf, carbRatio: seg.carbRatio);

    final cgm = <CgmSample>[];
    var bg = 132.0; // ~7.3 mmol/L overnight starting point
    for (var t = start;
        !t.isAfter(now);
        t = t.add(const Duration(minutes: step))) {
      final hour = t.hour + t.minute / 60.0;

      // Insulin pulling down.
      final act = iob.total(boluses, basal, t).activityUnitsPerMin;
      var delta = -act * seg.isf * step;

      // Carbs pushing up.
      for (final c in carbs) {
        final mins = t.difference(c.time).inMinutes.toDouble();
        if (mins < 0) continue;
        delta += carbModel.absorptionRate(
                mins, c.grams, c.absorptionMinutes.toDouble()) *
            csf *
            step;
      }

      // Dawn phenomenon: gentle rise 4–7am.
      if (hour >= 4 && hour < 7) delta += 1.1 * step * 0.2;

      // Post-lunch walk 13:30–14:15: aerobic dip.
      final walk = at(13, 30);
      if (!t.isBefore(walk) &&
          t.isBefore(walk.add(const Duration(minutes: 45)))) {
        delta -= 1.6 * step;
      }

      // Sensor noise.
      delta += (rng.nextDouble() - 0.5) * 3.0;

      bg = (bg + delta).clamp(45.0, 320.0);

      // Nocturnal compression low ~03:10: a sharp pressure dip + rebound, NOT real.
      final comp = at(3, 10);
      var reported = bg;
      var isCompression = false;
      final dt = t.difference(comp).inMinutes;
      if (dt >= 0 && dt <= 15) {
        final dip = (15 - (dt - 7).abs()) * 6.0;
        // bg is already floored at 45 above, so [45, bg] is always a valid range.
        reported = (bg - dip).clamp(45.0, bg);
        isCompression = reported < 70;
      }

      cgm.add(CgmSample(
        time: t,
        mgdl: reported,
        trend: _trendFor(cgm.isEmpty ? reported : cgm.last.mgdl, reported, step),
        compressionLow: isCompression,
      ));
    }

    // Context: a slightly-short, slightly-poor night to make the sensitivity model
    // and morning summary say something interesting.
    const context = ContextFeatures(
      sleepHours: 5.8,
      sleepEfficiency: 0.86,
      overnightHrvRmssd: 42,
      restingHr: 61,
      priorDayExerciseLoad: 0.4,
      menstrualLutealPhase: 0,
      illnessFlag: 0,
      baselineHrv: 55,
      baselineRestingHr: 56,
    );

    return SimulatedDay(
      start: start,
      end: now,
      cgm: cgm,
      boluses: boluses,
      basal: basal,
      carbs: carbs,
      settings: s,
      context: context,
    );
  }

  static GlucoseTrend _trendFor(double prev, double cur, int stepMin) {
    final roc = (cur - prev) / stepMin;
    if (roc >= 3.0) return GlucoseTrend.doubleUp;
    if (roc >= 1.5) return GlucoseTrend.singleUp;
    if (roc >= 0.5) return GlucoseTrend.fortyFiveUp;
    if (roc > -0.5) return GlucoseTrend.flat;
    if (roc > -1.5) return GlucoseTrend.fortyFiveDown;
    if (roc > -3.0) return GlucoseTrend.singleDown;
    return GlucoseTrend.doubleDown;
  }

  static const TherapySettings _defaultSettings = TherapySettings(
    segments: [
      TherapySegment(
        startMinuteOfDay: 0,
        isf: 50, // ~2.8 mmol/L per unit
        carbRatio: 10,
        targetMgdl: 108,
        basalUnitsPerHour: 0.75,
      ),
    ],
    maxBolusUnits: 20,
  );
}
