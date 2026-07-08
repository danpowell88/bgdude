/// Decides when to fire a real-time glucose nudge from the forecast. Pure logic with a
/// per-kind cooldown so the user isn't spammed. These alerts are ADDITIVE to the
/// pump/CGM's own alarms — they never replace them, and they lead with an action.
library;

import '../core/units.dart';
import '../ml/forecaster.dart';

enum GlucoseAlertKind { urgentLow, predictedLow, predictedHigh }

class GlucoseAlert {
  const GlucoseAlert({
    required this.kind,
    required this.title,
    required this.body,
  });

  final GlucoseAlertKind kind;
  final String title;
  final String body;
}

class AlertMonitor {
  const AlertMonitor({
    this.lowMgdl = 70,
    this.urgentLowMgdl = 55,
    this.highMgdl = 200,
    this.cooldown = const Duration(minutes: 30),
    this.rescueCarbsGrams = 15,
  });

  final double lowMgdl;
  final double urgentLowMgdl;
  final double highMgdl;
  final Duration cooldown;
  final double rescueCarbsGrams;

  /// Evaluate the current forecast. Returns an alert to fire (respecting the cooldown
  /// in [lastFired]) or null. The caller records the fire time.
  GlucoseAlert? evaluate({
    required List<HorizonForecast> forecasts,
    required double currentMgdl,
    required DateTime now,
    required Map<GlucoseAlertKind, DateTime> lastFired,
    GlucoseUnit unit = GlucoseUnit.mmol,
    // TASK-93: during an announced workout, glucose commonly drifts down, so a
    // predicted-HIGH nudge is noise — suppress it. Lows/urgent-lows are NEVER suppressed.
    bool suppressPredictedHigh = false,
  }) {
    if (forecasts.isEmpty) return null;
    bool cool(GlucoseAlertKind k) {
      final last = lastFired[k];
      if (last == null) return true;
      final elapsed = now.difference(last);
      // TASK-184: a DST fall-back / manual clock change makes elapsed negative —
      // fail open so an urgent low is never suppressed for the repeated hour.
      if (elapsed.isNegative) return true;
      return elapsed >= cooldown;
    }

    final minF = forecasts.reduce((a, b) => a.mgdl < b.mgdl ? a : b);
    final maxF = forecasts.reduce((a, b) => a.mgdl > b.mgdl ? a : b);
    String g(double m) => '${Mgdl(m).display(unit)} ${unit.label}';

    // TASK-303: urgentLow is checked FIRST, independently of the predictedLow branch
    // below -- defense-in-depth against a mis-ordered/corrupt threshold config
    // (lowMgdl <= urgentLowMgdl) that would otherwise make urgentLow unreachable by
    // nesting it inside a `minF.mgdl < lowMgdl` gate a too-low lowMgdl could already
    // fail. Deliberately keeps the SAME `currentMgdl > lowMgdl` outer gate the old
    // nested check used (not `currentMgdl > urgentLowMgdl` on its own) -- for a
    // correctly-ordered config (urgentLowMgdl < lowMgdl, the only legitimate one)
    // this fires in EXACTLY the same cases as before; only a mis-ordered config's
    // behaviour changes (from "fires nothing" to "fires the urgent alert it should").
    if (minF.mgdl < urgentLowMgdl && currentMgdl > lowMgdl) {
      if (!cool(GlucoseAlertKind.urgentLow)) return null;
      return GlucoseAlert(
        kind: GlucoseAlertKind.urgentLow,
        title: 'Low predicted soon',
        body: 'Heading to ${g(minF.mgdl)} in ~${minF.horizonMinutes} min — '
            'consider ${rescueCarbsGrams.round()}g fast carbs now.',
      );
    }

    // Predicted-low (non-urgent): gate on the low threshold and that kind's cooldown.
    // Reaching here means the urgent check above didn't fire, so this never cascades
    // into a lesser low alert on top of an urgent one for the same dip.
    if (minF.mgdl < lowMgdl && currentMgdl > lowMgdl) {
      if (!cool(GlucoseAlertKind.predictedLow)) return null;
      return GlucoseAlert(
        kind: GlucoseAlertKind.predictedLow,
        title: 'Low ahead',
        body: 'Predicted ${g(minF.mgdl)} in ~${minF.horizonMinutes} min. '
            '~${rescueCarbsGrams.round()}g would head it off.',
      );
    }

    if (!suppressPredictedHigh &&
        maxF.mgdl > highMgdl &&
        currentMgdl < maxF.mgdl &&
        cool(GlucoseAlertKind.predictedHigh)) {
      return GlucoseAlert(
        kind: GlucoseAlertKind.predictedHigh,
        title: 'Trending high',
        body: 'Predicted ${g(maxF.mgdl)} in ~${maxF.horizonMinutes} min. '
            'Check IOB before correcting.',
      );
    }

    return null;
  }
}
