/// The pump's own configuration, mirrored read-only (issue #85).
///
/// bgdude never writes pump settings (decision-1), so this is a window, not a form.
/// Its value is that several of these silently shape behaviour the user would
/// otherwise attribute to the app: auto-shutdown stops delivery after an idle period,
/// and the pump's low-insulin threshold is why it warns about the reservoir at a
/// different moment than bgdude does.
library;

import 'package:flutter/material.dart';

import '../../pump/pump_snapshot.dart';

class PumpConfigCard extends StatelessWidget {
  const PumpConfigCard({super.key, required this.snapshot});

  final PumpSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final snap = snapshot;
    // Absent, not empty: a card listing nothing would read as "the pump has no
    // settings", which is never true — it just hasn't told us.
    if (snap == null || !snap.hasPumpConfiguration) return const SizedBox.shrink();
    final small = Theme.of(context).textTheme.bodySmall;

    final rows = <String>[
      if (snap.autoShutdownEnabled != null)
        snap.autoShutdownEnabled == true
            ? 'Auto-shutdown after ${snap.autoShutdownHours ?? '?'} h idle'
            : 'Auto-shutdown off',
      if (snap.lowInsulinThresholdUnits != null)
        'Pump warns at ${snap.lowInsulinThresholdUnits} U left',
      if (snap.cannulaPrimeSizeUnits != null)
        'Cannula prime ${snap.cannulaPrimeSizeUnits!.toStringAsFixed(2)} U',
      if (snap.quickBolusEnabled != null)
        'Quick bolus ${snap.quickBolusEnabled == true ? 'on' : 'off'}',
      if (snap.featureLocked == true) 'Pump feature lock is ON',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pump configuration',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(r, style: small),
              ),
            const SizedBox(height: 6),
            Text('Read-only — change these on the pump itself.',
                style: small?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
