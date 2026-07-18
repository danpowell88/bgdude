/// "What my pump is showing right now" — the HomeScreenMirror icons (issue #84).
///
/// The pump renders its own status as a row of icons; op 57 reports which ones. This
/// translates each enum into a glyph plus a plain-language line, because the enum names
/// are pump-firmware vocabulary (`STATE_GRAY`, `HIDE_ICON`) that means nothing to the
/// person holding the phone.
///
/// **Null is "unknown", never "off".** Firmware that doesn't answer op 57 leaves these
/// unset, and rendering that as "Basal delivering normally" would state something about
/// the pump the app was never told.
library;

import 'package:flutter/material.dart';

import '../../pump/pump_snapshot.dart';

/// One decoded row: what to draw, and what it means in words.
class MirrorRow {
  const MirrorRow(this.icon, this.label, {this.warn = false});
  final IconData icon;
  final String label;

  /// Rendered in the error colour — a state the user would want to notice.
  final bool warn;
}

class PumpMirrorPanel extends StatelessWidget {
  const PumpMirrorPanel({super.key, required this.snapshot});

  final PumpSnapshot? snapshot;

  /// Enum name → glyph + plain language. Unknown names fall through to a readable
  /// form of the raw value rather than being dropped: a pump reporting something this
  /// build hasn't seen is worth showing, not hiding.
  static MirrorRow? basalRow(String? name) => switch (name) {
        null => null,
        'SUSPEND' => const MirrorRow(Icons.pause_circle_outline,
            'Basal delivery suspended', warn: true),
        'BASAL' => const MirrorRow(Icons.water_drop_outlined, 'Basal delivering'),
        'ZERO_BASAL' => const MirrorRow(Icons.water_drop_outlined,
            'Basal at zero (Control-IQ)', warn: true),
        'TEMP_RATE' =>
          const MirrorRow(Icons.speed_outlined, 'Temp basal rate active'),
        'HIDE_ICON' => null,
        _ => MirrorRow(Icons.help_outline, 'Basal: ${_humanise(name)}'),
      };

  static MirrorRow? controlIqRow(String? name) => switch (name) {
        null => null,
        'STATE_GRAY' => const MirrorRow(
            Icons.auto_mode_outlined, 'Control-IQ not actively adjusting'),
        'STATE_BLUE' =>
          const MirrorRow(Icons.auto_mode, 'Control-IQ increasing insulin'),
        'STATE_ORANGE' => const MirrorRow(
            Icons.auto_mode, 'Control-IQ reducing insulin', warn: true),
        'STATE_RED' => const MirrorRow(Icons.auto_mode,
            'Control-IQ stopped insulin (predicted low)', warn: true),
        'HIDE_ICON' => null,
        _ => MirrorRow(Icons.help_outline, 'Control-IQ: ${_humanise(name)}'),
      };

  static MirrorRow? cgmAlertRow(String? name) => switch (name) {
        null || 'NO_ERROR' || 'HIDE_ICON' => null,
        _ => MirrorRow(Icons.sensors_off_outlined,
            'CGM alert: ${_humanise(name)}', warn: true),
      };

  static MirrorRow? bolusRow(String? name) => switch (name) {
        null || 'HIDE_ICON' => null,
        'BOLUS' => const MirrorRow(Icons.colorize_outlined, 'Bolus delivering'),
        _ => MirrorRow(Icons.colorize_outlined, 'Bolus: ${_humanise(name)}'),
      };

  /// `STATE_GRAY` → `state gray`. Only used for values this build doesn't know, so a
  /// new firmware constant still reads as words rather than as shouting.
  static String _humanise(String raw) =>
      raw.toLowerCase().replaceAll('_', ' ');

  List<MirrorRow> get _rows => [
        for (final r in [
          basalRow(snapshot?.basalStatusIcon),
          controlIqRow(snapshot?.apControlStateIcon),
          cgmAlertRow(snapshot?.cgmAlertIcon),
          bolusRow(snapshot?.bolusStatusIcon),
        ])
          if (r != null) r,
      ];

  @override
  Widget build(BuildContext context) {
    final snap = snapshot;
    // Nothing to mirror: either the pump never answered op 57, or every icon is
    // hidden. Both mean "no panel" rather than an empty box implying all-clear.
    if (snap == null || !snap.hasHomeScreenMirror) return const SizedBox.shrink();
    final rows = _rows;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('On the pump right now',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text('Nothing showing — no alerts or special states.',
                  style: Theme.of(context).textTheme.bodySmall)
            else
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(r.icon,
                          size: 18, color: r.warn ? scheme.error : null),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.label)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
