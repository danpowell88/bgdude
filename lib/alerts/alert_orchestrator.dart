/// Pure alert decision core (TASK-116): everything `AlertService.onSnapshot` decides,
/// with no Riverpod, no clock reads, no notifications and no I/O. The provider wrapper
/// gathers a value [AlertCycleInput] from the live app, calls
/// [AlertOrchestrator.evaluate], and owns firing/dedup and `NotificationService.show`.
///
/// Every decision path is therefore unit-testable in isolation — the highest-safety
/// code in the app no longer needs a live `Ref` to exercise.
library;

import '../analytics/insulin_math.dart';
import '../analytics/predictor.dart';
import '../analytics/rescue_carbs.dart';
import '../core/samples.dart';
import '../core/sleep_window.dart';
import '../core/units.dart';
import '../insights/alert_monitor.dart';
import '../insights/alert_thresholds.dart';
import '../insights/anomaly_detector.dart';
import '../insights/care_detectors.dart';
import '../insights/effective_low_threshold.dart';
import '../insights/exercise_mode.dart';
import '../insights/ketone_risk.dart';
import '../insights/notification_prefs.dart';
import '../insights/post_meal_movement.dart';
import '../ml/forecaster.dart';
import '../profile/user_profile.dart';
import '../pump/battery_drain.dart';
import '../pump/battery_history.dart';
import '../pump/pump_snapshot.dart';
import '../state/day_data.dart';

/// Per-category repeat-cooldown tracker (TASK-184). Wall-clock elapsed time can go
/// NEGATIVE across a DST fall-back or a manual clock change; a negative elapsed is
/// treated as eligible (fail-open) — the cost is one possibly-early re-alert around
/// a clock change, never a suppressed urgent low during the repeated hour.
class CooldownGate {
  final Map<NotificationCategory, DateTime> _lastFired = {};

  /// Whether [c]'s cooldown of [interval] has elapsed at [now]. Pure check — does
  /// not record a fire (see [markFired]).
  bool passed(NotificationCategory c, DateTime now, Duration interval) {
    final last = _lastFired[c];
    if (last == null) return true;
    final elapsed = now.difference(last);
    // Clock jumped backwards — fail open rather than suppress a re-alert.
    if (elapsed.isNegative) return true;
    return elapsed >= interval;
  }

  void markFired(NotificationCategory c, DateTime now) => _lastFired[c] = now;
}

/// How the wrapper should treat the category cooldown around the send.
enum AlertUrgency {
  /// Record the fire only AFTER a successful send, so a failed send (e.g. an
  /// urgent low) is retried on the next cycle rather than silently suppressed.
  critical,

  /// Record the fire optimistically before the send (fine for nudges).
  normal,
}

/// One alert the orchestrator has decided should fire this cycle, before any
/// cooldown/enabled gating (which stays in the provider wrapper).
class AlertDecision {
  const AlertDecision({
    required this.category,
    required this.title,
    required this.body,
    this.urgency = AlertUrgency.normal,
    this.bigText = false,
    this.bypassCooldown = false,
  });

  final NotificationCategory category;
  final String title;
  final String body;
  final AlertUrgency urgency;

  /// Expand the notification body (long sick-day guidance).
  final bool bigText;

  /// Fire regardless of the category cooldown (a NEW pump alarm must always
  /// surface, even mid-cooldown of the previous one).
  final bool bypassCooldown;
}

/// Low/high/urgent-low lines after all safety modifiers have been applied.
class EffectiveThresholds {
  const EffectiveThresholds({
    required this.lowMgdl,
    required this.highMgdl,
    required this.urgentLowMgdl,
    this.lowReasons = const [],
  });

  final double lowMgdl;
  final double highMgdl;
  final double urgentLowMgdl;

  /// Which low-line modifiers were active (from [EffectiveLowThreshold]).
  final List<String> lowReasons;
}

/// Start from the user's own alert thresholds (per-time-of-day band, with a carb entry
/// in the last 2h selecting the post-meal row) for the high/urgent-low lines; the low
/// line itself is [effectiveLow] — already composed by [EffectiveLowThreshold.compute]
/// in the provider wrapper (TASK-231) so the alert cycle and the coaching path (pre-bolus
/// guard, rescue-carb advice, TASK-147) can never independently diverge on it. The
/// post-meal window check itself is also shared (see [isPostMealWindow]) so the two
/// paths can't pick a different band row either.
EffectiveThresholds resolveEffectiveThresholds({
  required AlertThresholds thresholds,
  required DateTime now,
  required List<CarbEntry> carbs,
  required EffectiveLowThreshold effectiveLow,
}) {
  final postMeal = isPostMealWindow(carbs, now);
  final band = thresholds.resolve(at: now, postMeal: postMeal);
  return EffectiveThresholds(
    lowMgdl: effectiveLow.mgdl,
    highMgdl: band.highMgdl,
    urgentLowMgdl: band.urgentLowMgdl,
    lowReasons: effectiveLow.reasons,
  );
}

/// Everything one alert cycle reads from the live app, as plain values. Pump-status
/// fields work without a CGM/prediction; the glucose paths need [state], [day] and
/// [profile] (all null together when no prediction is available).
class AlertCycleInput {
  const AlertCycleInput({
    required this.now,
    this.snapshot,
    this.lastAlarmSignature,
    this.batterySamples = const [],
    this.state,
    this.forecasts = const [],
    this.unit = GlucoseUnit.mmol,
    this.thresholds = const AlertThresholds(),
    this.day,
    this.profile,
    this.effectiveLow,
    this.exercise,
    this.rescue,
    this.siteAgeHours,
    this.illnessActive = false,
    this.recentActivityFeature = 0.0,
  });

  final DateTime now;
  final PumpSnapshot? snapshot;

  /// The previous cycle's active-alarm signature (see [AlertCycleResult.alarmSignature]).
  final String? lastAlarmSignature;

  /// Battery history including the latest sample, for the drain estimate.
  final List<BatterySample> batterySamples;

  final PredictionState? state;

  /// Calibrated forecasts for [state].
  final List<HorizonForecast> forecasts;
  final GlucoseUnit unit;
  final AlertThresholds thresholds;
  final DayData? day;
  final UserProfile? profile;

  /// The composed low line (TASK-231) — from `effectiveLowThresholdProvider`, the same
  /// value the coaching path (pre-bolus guard, rescue-carb advice) uses. Null only when
  /// [state] is also null (no live prediction this cycle, see [_glucoseCycle]'s guard).
  final EffectiveLowThreshold? effectiveLow;
  final ExercisePlan? exercise;
  final RescueCarbAdvice? rescue;
  final double? siteAgeHours;
  final bool illnessActive;

  /// Activity feature at [now] (≈ steps/min ÷ 100) from the health sampler.
  final double recentActivityFeature;
}

class AlertCycleResult {
  const AlertCycleResult({required this.decisions, this.alarmSignature});

  /// Decisions in fire order; the wrapper gates each on its category cooldown.
  final List<AlertDecision> decisions;

  /// The active-alarm signature to carry into the next cycle (null when no
  /// alarms are active; unchanged from the input when there was no snapshot).
  final String? alarmSignature;
}

/// The pure alert brain. Stateless and const — all cross-cycle state (cooldowns, the
/// last alarm signature, battery history) lives with the caller and flows in as values.
class AlertOrchestrator {
  const AlertOrchestrator();

  /// Below this many units left, warn about the reservoir.
  static const double reservoirLowUnits = 15.0;

  /// The pump raises its own critical-battery alarms; this is the earlier,
  /// predictive heads-up.
  static const int batteryLowPercent = 20;
  static const Duration batteryWarnWithin = Duration(hours: 6);

  static NotificationCategory _categoryFor(GlucoseAlertKind k) => switch (k) {
        GlucoseAlertKind.urgentLow => NotificationCategory.urgentLow,
        GlucoseAlertKind.predictedLow => NotificationCategory.predictedLow,
        GlucoseAlertKind.predictedHigh => NotificationCategory.predictedHigh,
      };

  AlertCycleResult evaluate(AlertCycleInput input) {
    final decisions = <AlertDecision>[];
    // Pump-status alerts (alarms + low reservoir + battery) come straight off the
    // snapshot and don't depend on a CGM/prediction being available, so decide them
    // first (matching the pre-extraction notification order).
    final alarmSignature = _pumpStatus(input, decisions);
    _glucoseCycle(input, decisions);
    return AlertCycleResult(decisions: decisions, alarmSignature: alarmSignature);
  }

  /// Surface active pump alarms, a low reservoir and a low/soon-empty battery from the
  /// latest snapshot. Returns the alarm signature to persist for the next cycle.
  String? _pumpStatus(AlertCycleInput input, List<AlertDecision> out) {
    final snap = input.snapshot;
    if (snap == null) return input.lastAlarmSignature;
    final now = input.now;

    // Active alarms/alerts on the pump. Fire when the active set changes (so a new
    // alarm notifies even mid-cooldown) and re-alert per the category's repeat
    // interval while it persists.
    String? alarmSignature;
    final active = [...snap.activeAlarms, ...snap.activeAlerts];
    if (active.isNotEmpty) {
      final signature = active.join('|');
      alarmSignature = signature;
      out.add(AlertDecision(
        category: NotificationCategory.pumpAlarm,
        title: snap.activeAlarms.isNotEmpty ? 'Pump alarm' : 'Pump alert',
        body: '${active.map(humanizeAlarm).join(', ')} — check your pump.',
        bypassCooldown: signature != input.lastAlarmSignature,
      ));
    }

    final reservoir = snap.reservoirUnits;
    if (reservoir != null && reservoir <= reservoirLowUnits) {
      out.add(AlertDecision(
        category: NotificationCategory.reservoirLow,
        title: 'Low reservoir',
        body: '~${reservoir.round()} U left — plan a cartridge change soon.',
      ));
    }

    _battery(snap, input, now, out);
    return alarmSignature;
  }

  /// Warn on a low battery level or a predicted soon-drain (e.g. "won't last the
  /// night"). No warning while charging.
  void _battery(PumpSnapshot snap, AlertCycleInput input, DateTime now,
      List<AlertDecision> out) {
    final pct = snap.batteryPercent;
    if (pct == null) return;
    if (snap.isCharging == true) return;

    final estimate =
        const BatteryDrainEstimator().estimate(input.batterySamples, now: now);
    final tte = estimate.timeToEmpty;
    final soon = tte != null && tte <= batteryWarnWithin;
    if (pct <= batteryLowPercent || soon) {
      final body = soon
          ? 'About ${_hoursText(tte)} of battery left at the current rate — '
              'charge before it runs out${_overnight(now, tte) ? ' (it won’t last the night)' : ''}.'
          : 'Pump battery at $pct% — charge it soon.';
      out.add(AlertDecision(
        category: NotificationCategory.batteryLow,
        title: 'Low pump battery',
        body: body,
      ));
    }
  }

  /// The CGM/prediction-driven paths: predicted low/high, post-meal walk nudge, rescue
  /// carbs, missed bolus, stubborn high, ketone check, and the anomaly catch-all.
  void _glucoseCycle(AlertCycleInput input, List<AlertDecision> out) {
    final state = input.state;
    final day = input.day;
    final profile = input.profile;
    final effectiveLow = input.effectiveLow;
    if (state == null || day == null || profile == null || effectiveLow == null) {
      return;
    }
    final now = input.now;
    final forecasts = input.forecasts;
    final exercise = input.exercise;
    // Tracks whether a *named* condition is present this cycle; the general anomaly
    // alert only fires as a catch-all when none is.
    var firedSpecific = false;

    final thresholds = resolveEffectiveThresholds(
      thresholds: input.thresholds,
      now: now,
      carbs: day.carbs,
      effectiveLow: effectiveLow,
    );

    // Evaluate without an internal cooldown — repeat/opt-out is governed by prefs in
    // the wrapper.
    final alert = AlertMonitor(
      cooldown: Duration.zero,
      lowMgdl: thresholds.lowMgdl,
      highMgdl: thresholds.highMgdl,
      urgentLowMgdl: thresholds.urgentLowMgdl,
    ).evaluate(
      forecasts: forecasts,
      currentMgdl: state.currentMgdl,
      now: now,
      lastFired: const {},
      unit: input.unit,
      // TASK-93: mute predicted-high nudges during an active workout (lows still fire).
      suppressPredictedHigh: exercise != null && exercise.affectsAt(now),
    );
    if (alert != null) {
      firedSpecific = true;
      out.add(AlertDecision(
        category: _categoryFor(alert.kind),
        title: alert.title,
        body: alert.body,
        urgency: AlertUrgency.critical,
      ));
    }

    // Post-meal "walk it off": a spike predicted soon after a meal, and not already
    // moving → suggest a short walk (a short post-meal walk blunts the spike).
    final ateRecently = day.carbs.any((c) =>
        !c.time.isAfter(now) &&
        now.difference(c.time) <= const Duration(minutes: 45));
    final peak = forecasts.isEmpty
        ? state.currentMgdl
        : forecasts.map((f) => f.mgdl).reduce((a, b) => a > b ? a : b);
    if (const PostMealMovementCoach().shouldNudge(
      ateWithinWindow: ateRecently,
      currentMgdl: state.currentMgdl,
      forecastPeakMgdl: peak,
      // activity feature ≈ steps/min ÷ 100
      recentStepsPerMin: input.recentActivityFeature * 100,
    )) {
      out.add(const AlertDecision(
        category: NotificationCategory.postMealMovement,
        title: 'A short walk would help',
        body: 'A post-meal rise is on the way — even 10 minutes of walking now will '
            'blunt the spike.',
      ));
    }

    // Rescue carbs: fire the act-now case (urgent) as its own category so it can be
    // tuned/opted separately from the predictive low alert above.
    final rescue = input.rescue;
    if (rescue != null && rescue.urgent) {
      firedSpecific = true;
      out.add(AlertDecision(
        category: NotificationCategory.rescueCarb,
        title: 'Take rescue carbs',
        body: '~${rescue.grams.round()}g fast carbs now — ${rescue.reason}',
      ));
    }

    // Care alerts: missed bolus and stubborn-high (possible site failure).
    final missed = const MissedBolusDetector().detect(
      cgm: day.cgm,
      boluses: day.boluses,
      carbs: day.carbs,
      basal: day.basal,
      settings: day.settings,
      now: now,
    );
    if (missed != null) {
      firedSpecific = true;
      out.add(AlertDecision(
        category: NotificationCategory.missedBolus,
        title: 'Missed bolus?',
        body: 'A ~${missed.estimatedCarbsGrams.round()}g rise with no bolus logged — '
            'correct now if you ate.',
      ));
    }

    final stubborn = const StubbornHighDetector().detect(
      cgm: day.cgm,
      boluses: day.boluses,
      basal: day.basal,
      settings: day.settings,
      siteAgeHours: input.siteAgeHours,
      now: now,
    );
    if (stubborn != null) {
      firedSpecific = true;
      out.add(AlertDecision(
        category: NotificationCategory.stubbornHigh,
        title: 'Stubborn high',
        body: stubborn.likelySiteIssue
            ? 'High for a while with insulin doing little, and your site is '
                '~${(stubborn.siteAgeHours! / 24).toStringAsFixed(1)} days old — '
                'consider a set change.'
            : 'High for a while with IOB not bringing it down — watch for a '
                'possible site issue.',
      ));
    }

    // Ketone / DKA sick-day prompt: sustained high + a ketone risk factor (illness,
    // likely site failure, or very high with minimal IOB).
    final iob =
        const IobCalculator().total(state.boluses, state.basal, now).units;
    final ketone = const KetoneRiskDetector().detect(
      cgm: day.cgm,
      iobUnits: iob,
      illnessActive: input.illnessActive,
      likelySiteIssue: stubborn?.likelySiteIssue ?? false,
      now: now,
    );
    if (ketone.suggestCheck) {
      firedSpecific = true;
      out.add(AlertDecision(
        category: NotificationCategory.ketoneCheck,
        title: 'Check ketones',
        body: ketone.reason,
        bigText: true,
      ));
    }

    // General anomaly catch-all: when no named condition above is present, flag glucose
    // that's moving faster than the carbs/insulin model expects — an early "something
    // out of the norm" heads-up (unannounced meal, sensor/site trouble, stress,
    // illness onset).
    if (!firedSpecific) {
      final current = state.currentMgdl;
      final expectedRoc = forecasts.isEmpty
          ? 0.0
          : (forecasts.first.mgdl - current) / forecasts.first.horizonMinutes;
      final anomaly = const AnomalyDetector()
          .detect(cgm: day.cgm, expectedRocMgdlPerMin: expectedRoc, now: now);
      if (anomaly.detected) {
        out.add(AlertDecision(
          category: NotificationCategory.anomalyDetected,
          title: 'Something looks unusual',
          body: anomaly.reason,
        ));
      }
    }
  }

  static String _hoursText(Duration d) {
    final h = d.inMinutes / 60.0;
    return h < 1 ? '${d.inMinutes} min' : '${h.toStringAsFixed(h < 3 ? 1 : 0)} h';
  }

  /// True when the predicted empty time lands during typical sleep hours (23:00–07:00).
  static bool _overnight(DateTime now, Duration tte) {
    final at = now.add(tte);
    return defaultAsleepAt(at);
  }

  /// Turn a pumpx2 enum-ish alarm name (e.g. "LOW_INSULIN_ALARM") into readable text.
  static String humanizeAlarm(String raw) {
    final words = raw
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return raw;
    return words.first[0].toUpperCase() +
        words.first.substring(1) +
        (words.length > 1 ? ' ${words.sublist(1).join(' ')}' : '');
  }
}
