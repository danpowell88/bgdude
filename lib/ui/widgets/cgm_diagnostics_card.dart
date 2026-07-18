/// CGM diagnostics and the pump's own alert thresholds (issue #90).
///
/// The point of mirroring the pump's thresholds is not decoration — it answers the
/// commonest confusion in a two-alerting-system setup: *why did one of them warn me
/// and not the other?* Showing both side by side, and naming the gap when they differ,
/// turns "the app is broken" into "they're set differently, and here's how".
///
/// bgdude's own alerts are deliberately NOT changed to match. The pump's alarms are the
/// safety net and are configured on the pump; silently re-pointing the app's thresholds
/// at them would move a safety boundary the user set, without being asked.
library;

import 'package:flutter/material.dart';

import '../../core/units.dart';
import '../../insights/alert_thresholds.dart';
import '../../pump/pump_snapshot.dart';

class CgmDiagnosticsCard extends StatelessWidget {
  const CgmDiagnosticsCard({
    super.key,
    required this.snapshot,
    required this.appThresholds,
    required this.unit,
  });

  final PumpSnapshot? snapshot;
  final AlertThresholds appThresholds;
  final GlucoseUnit unit;

  /// True when the pump reported at least one threshold — the difference between
  /// "the pump has no alerts" and "the pump never told us".
  static bool hasThresholds(PumpSnapshot? s) =>
      s?.cgmHighAlertMgdl != null || s?.cgmLowAlertMgdl != null;

  /// A plain-language note when a pump threshold and the app's differ enough to
  /// explain a divergent alert. Null when they agree, or when either is unknown —
  /// a mismatch note about a number nobody has is noise.
  static String? mismatchNote({
    required int? pumpLow,
    required int? pumpHigh,
    required double appLow,
    required double appHigh,
  }) {
    final parts = <String>[];
    // 1 mg/dL of slack: the pump stores integers and the app doubles, so an exact
    // comparison would report a "mismatch" that is really a rounding artefact.
    if (pumpLow != null && (pumpLow - appLow).abs() >= 1) {
      parts.add(pumpLow < appLow
          ? 'the pump warns lower than bgdude, so bgdude alerts first'
          : 'the pump warns higher than bgdude, so the pump alerts first');
    }
    if (pumpHigh != null && (pumpHigh - appHigh).abs() >= 1) {
      parts.add(pumpHigh > appHigh
          ? 'for highs the pump warns later than bgdude'
          : 'for highs the pump warns sooner than bgdude');
    }
    if (parts.isEmpty) return null;
    return 'Thresholds differ — ${parts.join('; ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final snap = snapshot;
    final hasAny = snap != null &&
        (hasThresholds(snap) || snap.cgmTransmitterId != null);
    // Nothing reported: render nothing rather than an empty card that reads as
    // "your CGM has no alerts configured".
    if (!hasAny) return const SizedBox.shrink();

    final small = Theme.of(context).textTheme.bodySmall;
    final note = mismatchNote(
      pumpLow: snap.cgmLowAlertMgdl,
      pumpHigh: snap.cgmHighAlertMgdl,
      appLow: appThresholds.lowMgdl,
      appHigh: appThresholds.highMgdl,
    );

    String show(int? mgdl, {required bool? enabled}) {
      if (mgdl == null) return '—';
      final v = '${Mgdl(mgdl.toDouble()).display(unit)} ${unit.label}';
      return enabled == false ? '$v (off)' : v;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CGM on the pump',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            if (snap.cgmTransmitterId != null)
              Text('Transmitter ${snap.cgmTransmitterId}', style: small),
            if (hasThresholds(snap)) ...[
              const SizedBox(height: 6),
              Text(
                'Pump alerts at '
                '${show(snap.cgmLowAlertMgdl, enabled: snap.cgmLowAlertEnabled)} low · '
                '${show(snap.cgmHighAlertMgdl, enabled: snap.cgmHighAlertEnabled)} high',
                style: small,
              ),
              Text(
                'bgdude alerts at '
                '${Mgdl(appThresholds.lowMgdl).display(unit)} low · '
                '${Mgdl(appThresholds.highMgdl).display(unit)} high',
                style: small,
              ),
            ],
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(note,
                    style: small?.copyWith(
                        color: Theme.of(context).colorScheme.primary)),
              ),
          ],
        ),
      ),
    );
  }
}
