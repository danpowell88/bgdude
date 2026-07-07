/// Per-decision tests of the pure alert brain (TASK-116): every path that used to be
/// inlined in `AlertService.onSnapshot` — pump alarms, reservoir, battery, predicted
/// low/high, post-meal walk, rescue carbs, missed bolus, stubborn high, ketone check,
/// anomaly catch-all — plus the composed threshold policy, exercised as plain values
/// with no Riverpod.
library;

import 'package:bgdude/alerts/alert_orchestrator.dart';
import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/analytics/rescue_carbs.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/units.dart';
import 'package:bgdude/insights/alert_thresholds.dart';
import 'package:bgdude/insights/effective_low_threshold.dart';
import 'package:bgdude/insights/exercise_mode.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/insights/workout_classifier.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:bgdude/profile/user_profile.dart';
import 'package:bgdude/pump/battery_history.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/state/day_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/samples.dart';

void main() {
  const orch = AlertOrchestrator();
  // Midday: the day segment applies and a battery-empty ETA lands before 23:00.
  final now = DateTime(2026, 7, 4, 12);

  DayData dayData({
    List<CgmSample> cgm = const [],
    List<BolusEvent> boluses = const [],
    List<CarbEntry> carbs = const [],
  }) =>
      DayData(
        start: now.subtract(const Duration(hours: 24)),
        end: now,
        cgm: cgm,
        boluses: boluses,
        basal: const [],
        carbs: carbs,
        settings: testTherapySettings(),
        context: null,
        isSimulated: false,
      );

  PredictionState stateAt(double mgdl, {List<BolusEvent> boluses = const []}) =>
      PredictionState(
        now: now,
        currentMgdl: mgdl,
        recentRocMgdlPerMin: 0,
        boluses: boluses,
        basal: const [],
        carbs: const [],
        settings: testTherapySettings(),
      );

  HorizonForecast forecast(int minutes, double mgdl) => HorizonForecast(
      horizonMinutes: minutes, mgdl: mgdl, lowerMgdl: mgdl - 10, upperMgdl: mgdl + 10);

  // Matches the default AlertThresholds' lowMgdl (70) with no active modifiers --
  // the "nothing special going on" coaching-path line these glucose-cycle tests are
  // set up around; TASK-231's own dedicated wiring test
  // (alert_effective_low_wiring_test.dart) covers a modifier actually changing this.
  const defaultEffectiveLow = EffectiveLowThreshold(mgdl: 70, reasons: []);

  AlertCycleInput glucoseInput({
    required PredictionState state,
    required DayData day,
    List<HorizonForecast> forecasts = const [],
    ExercisePlan? exercise,
    RescueCarbAdvice? rescue,
    double? siteAgeHours,
    bool illnessActive = false,
    double recentActivityFeature = 0.0,
    EffectiveLowThreshold effectiveLow = defaultEffectiveLow,
  }) =>
      AlertCycleInput(
        now: now,
        state: state,
        day: day,
        profile: const UserProfile(),
        effectiveLow: effectiveLow,
        forecasts: forecasts,
        unit: GlucoseUnit.mgdl,
        exercise: exercise,
        rescue: rescue,
        siteAgeHours: siteAgeHours,
        illnessActive: illnessActive,
        recentActivityFeature: recentActivityFeature,
      );

  List<NotificationCategory> categories(AlertCycleResult r) =>
      [for (final d in r.decisions) d.category];

  group('resolveEffectiveThresholds', () {
    // TASK-231: the low-line MODIFIER composition (impaired-awareness, alcohol,
    // exercise, weather, compose-via-max) is no longer this function's job -- it's
    // done once, upstream, by effectiveLowThresholdProvider (same policy as the
    // coaching path) and handed in as `effectiveLow`. That composition is pinned at
    // its source in effective_low_threshold_test.dart; duplicating it here again
    // would just assert this function passes through whatever it's given, which is
    // true by construction and proves nothing about the wiring (see
    // alert_effective_low_wiring_test.dart for the actual end-to-end proof). What's
    // still this function's own job: picking the high/urgent-low band via the
    // post-meal window, and passing the given low line straight through.
    EffectiveThresholds resolve({
      AlertThresholds thresholds = const AlertThresholds(),
      List<CarbEntry> carbs = const [],
      EffectiveLowThreshold effectiveLow = defaultEffectiveLow,
    }) =>
        resolveEffectiveThresholds(
          thresholds: thresholds,
          now: now,
          carbs: carbs,
          effectiveLow: effectiveLow,
        );

    test('defaults pass through unmodified', () {
      final t = resolve();
      expect(t.lowMgdl, 70);
      expect(t.highMgdl, 200);
      expect(t.urgentLowMgdl, 55);
    });

    test('the given effectiveLow flows straight through as lowMgdl/lowReasons', () {
      final t = resolve(
          effectiveLow:
              const EffectiveLowThreshold(mgdl: 78, reasons: ['impaired-awareness risk (+8)']));
      expect(t.lowMgdl, 78);
      expect(t.lowReasons, ['impaired-awareness risk (+8)']);
    });

    test('a carb entry in the last 2h selects the post-meal band', () {
      final withPostMeal = AlertThresholds(segments: {
        AlertSegment.postMeal:
            AlertBand(lowMgdl: 70, highMgdl: 250, urgentLowMgdl: 55),
      });
      final t = resolve(
        thresholds: withPostMeal,
        carbs: [CarbEntry(time: now.subtract(const Duration(hours: 1)), grams: 40)],
      );
      expect(t.highMgdl, 250);
      // No recent carbs → the day band applies.
      expect(resolve(thresholds: withPostMeal).highMgdl, 200);
    });
  });

  group('pump alarm', () {
    PumpSnapshot snapWith({List<String> alarms = const [], List<String> alerts = const []}) =>
        PumpSnapshot(time: now, activeAlarms: alarms, activeAlerts: alerts);

    test('a NEW alarm fires with bypassCooldown and a readable body', () {
      final r = orch.evaluate(AlertCycleInput(
          now: now, snapshot: snapWith(alarms: ['LOW_INSULIN_ALARM'])));
      expect(categories(r), [NotificationCategory.pumpAlarm]);
      final d = r.decisions.single;
      expect(d.bypassCooldown, isTrue);
      expect(d.title, 'Pump alarm');
      expect(d.body, contains('Low insulin alarm'));
      expect(r.alarmSignature, 'LOW_INSULIN_ALARM');
    });

    test('the SAME persisting alarm re-alerts only via the cooldown', () {
      final r = orch.evaluate(AlertCycleInput(
        now: now,
        snapshot: snapWith(alarms: ['LOW_INSULIN_ALARM']),
        lastAlarmSignature: 'LOW_INSULIN_ALARM',
      ));
      expect(r.decisions.single.bypassCooldown, isFalse);
    });

    test('alerts-only sets get the softer "Pump alert" title', () {
      final r = orch.evaluate(AlertCycleInput(
          now: now, snapshot: snapWith(alerts: ['LOW_POWER_ALERT'])));
      expect(r.decisions.single.title, 'Pump alert');
    });

    test('no active alarms clears the signature', () {
      final r = orch.evaluate(AlertCycleInput(
          now: now, snapshot: snapWith(), lastAlarmSignature: 'OLD'));
      expect(r.decisions, isEmpty);
      expect(r.alarmSignature, isNull);
    });

    test('no snapshot preserves the previous signature', () {
      final r = orch.evaluate(AlertCycleInput(now: now, lastAlarmSignature: 'OLD'));
      expect(r.alarmSignature, 'OLD');
    });
  });

  group('reservoir', () {
    test('warns at or below 15 U', () {
      final r = orch.evaluate(AlertCycleInput(
          now: now, snapshot: PumpSnapshot(time: now, reservoirUnits: 12)));
      expect(categories(r), [NotificationCategory.reservoirLow]);
      expect(r.decisions.single.body, contains('~12 U left'));
    });

    test('quiet above 15 U', () {
      final r = orch.evaluate(AlertCycleInput(
          now: now, snapshot: PumpSnapshot(time: now, reservoirUnits: 40)));
      expect(r.decisions, isEmpty);
    });
  });

  group('battery', () {
    test('low percent warns even with no drain history', () {
      final r = orch.evaluate(AlertCycleInput(
          now: now, snapshot: PumpSnapshot(time: now, batteryPercent: 15)));
      expect(categories(r), [NotificationCategory.batteryLow]);
      expect(r.decisions.single.body, contains('15%'));
    });

    test('no warning while charging', () {
      final r = orch.evaluate(AlertCycleInput(
          now: now,
          snapshot:
              PumpSnapshot(time: now, batteryPercent: 15, isCharging: true)));
      expect(r.decisions, isEmpty);
    });

    test('a healthy percent with a fast drain still warns with an ETA', () {
      final samples = [
        for (var h = 3; h >= 0; h--)
          BatterySample(
              time: now.subtract(Duration(hours: h)), percent: 35 + 15 * h),
      ];
      final r = orch.evaluate(AlertCycleInput(
        now: now,
        snapshot: PumpSnapshot(time: now, batteryPercent: 35),
        batterySamples: samples,
      ));
      expect(categories(r), [NotificationCategory.batteryLow]);
      expect(r.decisions.single.body, contains('of battery left'));
    });
  });

  group('predicted low/high (forecast alerts)', () {
    test('a predicted low is a critical decision', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(100),
        day: dayData(),
        forecasts: [forecast(30, 60)],
      ));
      expect(categories(r), [NotificationCategory.predictedLow]);
      expect(r.decisions.single.urgency, AlertUrgency.critical);
    });

    test('a predicted urgent low outranks the plain low', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(100),
        day: dayData(),
        forecasts: [forecast(20, 50)],
      ));
      expect(categories(r), [NotificationCategory.urgentLow]);
    });

    test('a predicted high fires when not exercising', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(150),
        day: dayData(),
        forecasts: [forecast(30, 220)],
      ));
      expect(categories(r), [NotificationCategory.predictedHigh]);
    });

    test('predicted-high is muted during an active workout (TASK-93)', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(150),
        day: dayData(),
        forecasts: [forecast(30, 220)],
        exercise: ExercisePlan(
          startAt: now.subtract(const Duration(minutes: 10)),
          durationMinutes: 60,
          type: WorkoutType.aerobic,
        ),
      ));
      expect(r.decisions, isEmpty);
    });

    test('no prediction state → only pump-status paths run', () {
      final r = orch.evaluate(AlertCycleInput(
          now: now, snapshot: PumpSnapshot(time: now, reservoirUnits: 10)));
      expect(categories(r), [NotificationCategory.reservoirLow]);
    });
  });

  group('post-meal walk nudge', () {
    final recentMeal = [
      CarbEntry(time: now.subtract(const Duration(minutes: 30)), grams: 45)
    ];

    test('nudges when a spike is predicted after a meal and not moving', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(130),
        day: dayData(carbs: recentMeal),
        forecasts: [forecast(30, 170)],
      ));
      expect(categories(r), [NotificationCategory.postMealMovement]);
    });

    test('stays quiet when already walking', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(130),
        day: dayData(carbs: recentMeal),
        forecasts: [forecast(30, 170)],
        recentActivityFeature: 0.5, // ≈50 steps/min
      ));
      expect(r.decisions, isEmpty);
    });
  });

  group('rescue carbs', () {
    test('the urgent act-now case fires its own category', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(70),
        day: dayData(),
        rescue: const RescueCarbAdvice(
            grams: 15, urgent: true, reason: 'dropping fast', working: []),
      ));
      expect(categories(r), [NotificationCategory.rescueCarb]);
      expect(r.decisions.single.body, contains('~15g fast carbs now'));
    });

    test('a non-urgent suggestion does not notify', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(90),
        day: dayData(),
        rescue: const RescueCarbAdvice(
            grams: 10, urgent: false, reason: 'mild dip ahead', working: []),
      ));
      expect(r.decisions, isEmpty);
    });
  });

  group('missed bolus', () {
    test('an uncovered post-meal rise asks about a missed bolus', () {
      final cgm = ramp(
        start: now.subtract(const Duration(minutes: 90)),
        startMgdl: 110,
        peakMgdl: 220,
        riseMinutes: 55,
        plateauMinutes: 35,
      );
      final r = orch.evaluate(glucoseInput(
        state: stateAt(220),
        day: dayData(cgm: cgm),
      ));
      expect(categories(r), [NotificationCategory.missedBolus]);
      expect(r.decisions.single.body, contains('no bolus logged'));
    });
  });

  group('stubborn high', () {
    final flatHigh = sustained(end: now, mgdl: 250, count: 31);
    final boluses = [
      BolusEvent(time: now.subtract(const Duration(minutes: 30)), units: 3)
    ];

    test('an old site is called out as the likely cause', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(250),
        day: dayData(cgm: flatHigh, boluses: boluses),
        siteAgeHours: 60,
      ));
      expect(categories(r), contains(NotificationCategory.stubbornHigh));
      final d = r.decisions
          .firstWhere((d) => d.category == NotificationCategory.stubbornHigh);
      expect(d.body, contains('set change'));
    });

    test('without a site age it warns to watch the site', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(250),
        day: dayData(cgm: flatHigh, boluses: boluses),
      ));
      final d = r.decisions
          .firstWhere((d) => d.category == NotificationCategory.stubbornHigh);
      expect(d.body, contains('possible site issue'));
    });
  });

  group('ketone check', () {
    test('very high with no insulin on board prompts a check (bigText)', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(320),
        day: dayData(cgm: sustained(end: now, mgdl: 320)),
      ));
      expect(categories(r), [NotificationCategory.ketoneCheck]);
      final d = r.decisions.single;
      expect(d.bigText, isTrue);
      expect(d.body.toLowerCase(), contains('insulin'));
    });

    test('sustained high while ill prompts a sick-day check', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(300, boluses: [
          BolusEvent(time: now.subtract(const Duration(minutes: 60)), units: 2)
        ]),
        day: dayData(cgm: sustained(end: now, mgdl: 300)),
        illnessActive: true,
      ));
      expect(categories(r), contains(NotificationCategory.ketoneCheck));
    });
  });

  group('anomaly catch-all', () {
    final fastRise = linear(
      start: now.subtract(const Duration(minutes: 15)),
      fromMgdl: 100,
      toMgdl: 160,
      minutes: 15,
    );

    test('an unexplained fast move fires when nothing else did', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(160),
        day: dayData(cgm: fastRise),
      ));
      expect(categories(r), [NotificationCategory.anomalyDetected]);
    });

    test('suppressed when a named condition already fired', () {
      final r = orch.evaluate(glucoseInput(
        state: stateAt(160),
        day: dayData(cgm: fastRise),
        rescue: const RescueCarbAdvice(
            grams: 15, urgent: true, reason: 'dropping fast', working: []),
      ));
      expect(categories(r), contains(NotificationCategory.rescueCarb));
      expect(categories(r),
          isNot(contains(NotificationCategory.anomalyDetected)));
    });
  });
}
