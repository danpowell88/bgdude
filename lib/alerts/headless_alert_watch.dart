/// Headless alert evaluation (issues #51 / #28, stage 3).
///
/// bgdude decides its forecast-based alerts inside the running app. When Android kills
/// the app to reclaim memory, that logic dies with it: the native backstop in
/// `PumpService` still catches a *current* reading below 55, but nothing predicts a low
/// that hasn't happened yet — which is the whole point of a predicted-low alert.
///
/// This runs the same pure [AlertMonitor] core in a headless isolate on a periodic
/// background task, so a predicted low is still caught with the screen off and the app
/// evicted.
///
/// Two things make that safe rather than a source of duplicate alerts, and both are pure
/// and tested here:
///
///  * **Shared cooldown state.** The foreground evaluator kept `lastFired` in memory
///    only, so cooldowns reset whenever the app restarted. With two independent
///    evaluators that is not merely untidy — it is how someone gets the same urgent-low
///    twice in a minute. [AlertFireLog] persists it so both share one record.
///  * **Foreground deference.** If the app evaluated recently, the headless pass does
///    nothing. The running app has better inputs (live CGM, IOB, exercise state); a
///    background pass second-guessing it is noise.
library;

import 'dart:convert';

import '../insights/alert_monitor.dart';
import '../ml/forecaster.dart';

/// The persisted record of when each alert kind last fired.
///
/// Stored as JSON so the foreground app and the headless isolate — separate processes,
/// with no shared memory — agree on cooldowns.
class AlertFireLog {
  const AlertFireLog(this.lastFired);

  final Map<GlucoseAlertKind, DateTime> lastFired;

  static const AlertFireLog empty = AlertFireLog({});

  String encode() => jsonEncode({
        for (final e in lastFired.entries)
          e.key.name: e.value.millisecondsSinceEpoch,
      });

  /// Anything unreadable decodes to empty rather than throwing.
  ///
  /// Failing open is the right default here: an empty log means the next alert fires
  /// immediately. The alternative — treating a corrupt log as "recently fired" — would
  /// silently suppress an urgent low, which is the exact failure this feature exists to
  /// prevent.
  static AlertFireLog decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return empty;
      final out = <GlucoseAlertKind, DateTime>{};
      for (final kind in GlucoseAlertKind.values) {
        final v = json[kind.name];
        if (v is int) out[kind] = DateTime.fromMillisecondsSinceEpoch(v);
      }
      return AlertFireLog(out);
    } catch (_) {
      return empty;
    }
  }

  AlertFireLog withFired(GlucoseAlertKind kind, DateTime at) =>
      AlertFireLog({...lastFired, kind: at});
}

/// How recently the foreground app must have evaluated for the headless pass to stand
/// down.
///
/// Comfortably longer than the app's own 5-minute cadence, so an ordinary gap between
/// foreground evaluations doesn't trigger a redundant background pass — but short enough
/// that a killed app is noticed within one background cycle.
const Duration foregroundFreshness = Duration(minutes: 12);

/// Whether the headless pass should evaluate at all.
///
/// [lastForegroundEvaluation] null means the app has never run or the record is gone —
/// evaluate, because "no evidence the app is alive" must not read as "the app is
/// handling it".
bool shouldEvaluateHeadless({
  required DateTime? lastForegroundEvaluation,
  required DateTime now,
}) {
  if (lastForegroundEvaluation == null) return true;
  final elapsed = now.difference(lastForegroundEvaluation);
  // A clock change can make this negative. Fail open: evaluating twice is a nuisance,
  // missing an urgent low is not.
  if (elapsed.isNegative) return true;
  return elapsed >= foregroundFreshness;
}

/// A short-horizon projection from recent readings, for use where the trained model
/// isn't available.
///
/// Deliberately a straight-line extrapolation of the recent rate, not an attempt to
/// reimplement the forecaster. The headless pass is a safety net: it should be
/// predictable and hard to get wrong, and a simple projection that catches a steep fall
/// is worth far more than a sophisticated one that might not load in a background
/// isolate.
///
/// Returns an empty list when there isn't enough recent data to justify a claim.
List<HorizonForecast> projectFromRecent(
  List<({DateTime time, double mgdl})> readings, {
  required DateTime now,
  List<int> horizonsMinutes = const [15, 30],
  Duration window = const Duration(minutes: 30),
}) {
  final recent = [
    for (final r in readings)
      if (!r.time.isAfter(now) && now.difference(r.time) <= window) r,
  ]..sort((a, b) => a.time.compareTo(b.time));
  if (recent.length < 2) return const [];

  final first = recent.first;
  final last = recent.last;
  final minutes = last.time.difference(first.time).inMinutes;
  if (minutes <= 0) return const [];

  // Stale data must not be extrapolated: a reading from 25 minutes ago projected
  // forward 30 is a guess about an hour that already happened.
  if (now.difference(last.time) > const Duration(minutes: 15)) return const [];

  final ratePerMinute = (last.mgdl - first.mgdl) / minutes;

  return [
    for (final h in horizonsMinutes)
      HorizonForecast(
        horizonMinutes: h,
        mgdl: (last.mgdl + ratePerMinute * h).clamp(20.0, 500.0),
        // A straight-line projection deserves a wide band; the number is an
        // extrapolation, not a model output, and the band should say so.
        lowerMgdl: (last.mgdl + ratePerMinute * h - 25).clamp(20.0, 500.0),
        upperMgdl: (last.mgdl + ratePerMinute * h + 25).clamp(20.0, 500.0),
      ),
  ];
}

/// The headless decision: given recent readings and the shared fire log, which alert (if
/// any) should fire now.
///
/// Pure. The isolate wiring around it — opening the database, posting the notification,
/// persisting the log — is deliberately kept outside so the decision can be tested
/// without any of it.
GlucoseAlert? evaluateHeadless({
  required List<({DateTime time, double mgdl})> readings,
  required AlertFireLog fireLog,
  required DateTime now,
  required DateTime? lastForegroundEvaluation,
  AlertMonitor monitor = const AlertMonitor(),
}) {
  if (!shouldEvaluateHeadless(
    lastForegroundEvaluation: lastForegroundEvaluation,
    now: now,
  )) {
    return null;
  }

  final forecasts = projectFromRecent(readings, now: now);
  if (forecasts.isEmpty) return null;

  final latest = [...readings]..sort((a, b) => a.time.compareTo(b.time));
  return monitor.evaluate(
    forecasts: forecasts,
    currentMgdl: latest.last.mgdl,
    now: now,
    lastFired: fireLog.lastFired,
    // The headless pass has no exercise state, so it cannot know a predicted high is
    // workout noise. Suppressing highs here is the conservative choice: a missed
    // predicted-high is an inconvenience, and a false one at 3am erodes trust in the
    // alerts that matter.
    suppressPredictedHigh: true,
  );
}

/// Persistence for the shared alert state.
///
/// Kept here rather than in the isolate wiring so the foreground app and the headless
/// pass use one implementation — two hand-rolled readers of the same key is how they
/// end up disagreeing about a cooldown.
class AlertWatchStore {
  const AlertWatchStore._();

  /// KvStore key for the shared fire log.
  static const String fireLogKey = 'alert_fire_log_v1';

  /// KvStore key for the foreground evaluator's heartbeat.
  static const String foregroundBeatKey = 'alert_foreground_beat_v1';

  /// Encodes a heartbeat. ISO-8601 so it stays readable in the diagnostics log.
  static String encodeBeat(DateTime at) => at.toIso8601String();

  /// Decodes a heartbeat; null for anything unreadable, which callers treat as
  /// "the app is not known to be alive" and therefore evaluate.
  static DateTime? decodeBeat(String? raw) =>
      raw == null || raw.trim().isEmpty ? null : DateTime.tryParse(raw);
}
