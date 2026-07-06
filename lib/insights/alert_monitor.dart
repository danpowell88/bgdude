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
      return last == null || now.difference(last) >= cooldown;
    }

    final minF = forecasts.reduce((a, b) => a.mgdl < b.mgdl ? a : b);
    final maxF = forecasts.reduce((a, b) => a.mgdl > b.mgdl ? a : b);
    String g(double m) => '${Mgdl(m).display(unit)} ${unit.label}';

    // Predicted-low handling: pick the severity, gate on THAT kind's cooldown, and do
    // not cascade to a lesser low alert (avoids double-alerting the same dip).
    if (minF.mgdl < lowMgdl && currentMgdl > lowMgdl) {
      final urgent = minF.mgdl < urgentLowMgdl && currentMgdl > urgentLowMgdl;
      final kind =
          urgent ? GlucoseAlertKind.urgentLow : GlucoseAlertKind.predictedLow;
      if (!cool(kind)) return null;
      return GlucoseAlert(
        kind: kind,
        title: urgent ? 'Low predicted soon' : 'Low ahead',
        body: urgent
            ? 'Heading to ${g(minF.mgdl)} in ~${minF.horizonMinutes} min — '
                'consider ${rescueCarbsGrams.round()}g fast carbs now.'
            : 'Predicted ${g(minF.mgdl)} in ~${minF.horizonMinutes} min. '
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
