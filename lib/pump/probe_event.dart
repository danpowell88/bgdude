/// Data model + request catalog for the Protocol Explorer (read-only pump probing).
///
/// A [ProbeEvent] is one message the native layer mirrored to us — either a request we
/// asked it to send (`direction == 'tx'`) or a response the pump returned (`'rx'`). The
/// [ProbeRequest] catalog is the menu of read-only `currentStatus` requests the explorer
/// can fire; the native side independently safety-gates every send, so this list is only a
/// convenience/labelling layer, never the security boundary.
library;

/// One captured pump message (sent request or received response).
class ProbeEvent {
  const ProbeEvent({
    required this.direction,
    required this.name,
    required this.timestampMs,
    this.opcode,
    this.characteristic,
    this.cargoHex,
    this.json,
    this.verbose,
  });

  /// 'tx' = a request we sent; 'rx' = a response the pump returned.
  final String direction;
  final String name;
  final int timestampMs;
  final int? opcode;
  final String? characteristic;
  final String? cargoHex;
  final String? json;
  final String? verbose;

  bool get isTx => direction == 'tx';

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timestampMs);

  /// Bytes in the message cargo (0 for empty/zero-length reads).
  int get cargoBytes {
    final h = cargoHex?.trim();
    if (h == null || h.isEmpty) return 0;
    return h.split(RegExp(r'\s+')).length;
  }

  static ProbeEvent fromMap(Map<Object?, Object?> map) => ProbeEvent(
        direction: map['direction'] as String? ?? 'rx',
        name: map['name'] as String? ?? 'Unknown',
        timestampMs:
            (map['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        opcode: (map['opcode'] as num?)?.toInt(),
        characteristic: map['characteristic'] as String?,
        cargoHex: map['cargoHex'] as String?,
        json: map['json'] as String?,
        verbose: map['verbose'] as String?,
      );

  /// A copy-friendly plaintext block for export/clipboard.
  String toReport() {
    final b = StringBuffer()
      ..writeln('${isTx ? '→ REQUEST' : '← RESPONSE'}  $name')
      ..writeln('time:    ${time.toIso8601String()}')
      ..writeln('opcode:  ${opcode ?? '—'}   characteristic: ${characteristic ?? '—'}')
      ..writeln('cargo:   ${cargoHex?.isNotEmpty == true ? cargoHex : '(empty)'}');
    if (json != null && json!.isNotEmpty) b.writeln('decoded: $json');
    return b.toString();
  }
}

/// A read-only request the explorer can fire.
class ProbeRequest {
  const ProbeRequest(
    this.className,
    this.label,
    this.note, {
    this.status = ProbeStatus.surfaced,
    this.params = const [],
  });

  /// The pumpx2 request class simple-name (in `request.currentStatus`).
  final String className;
  final String label;
  final String note;
  final ProbeStatus status;

  /// Optional integer constructor parameters (currently IDPSegment / HistoryLog only).
  final List<String> params;

  bool get parametric => params.isNotEmpty;
}

enum ProbeStatus {
  /// bgdude already reads and surfaces this today.
  surfaced,

  /// Documented in pump-protocol.md as a known opportunity, not yet surfaced.
  opportunity,

  /// Undocumented / experimental — exact fields unknown; fire to discover.
  experimental,
}

/// Grouped catalog of read-only requests, drawn from the pumpx2 1.9.0 message set. Firing
/// any of these and inspecting the decoded JSON + raw cargo is how we discover fields the
/// app doesn't model yet. Everything here targets the CURRENT_STATUS characteristic.
class ProbeCatalog {
  static const List<ProbeRequestGroup> groups = [
    ProbeRequestGroup('Core status (already surfaced)', [
      ProbeRequest('ApiVersionRequest', 'API version', 'BLE API major/minor.'),
      ProbeRequest('PumpVersionRequest', 'Pump version', 'ARM firmware version.'),
      ProbeRequest('TimeSinceResetRequest', 'Time since reset',
          'Pump uptime — anchors timestamps.'),
      ProbeRequest('CurrentBatteryV2Request', 'Battery (v2)',
          'Charge % + charging state.'),
      ProbeRequest('InsulinStatusRequest', 'Insulin status', 'Reservoir units remaining.'),
      ProbeRequest('ControlIQIOBRequest', 'IOB (Control-IQ)', 'Insulin on board.'),
      ProbeRequest('ControlIQInfoV2Request', 'Control-IQ info (v2)',
          'Closed-loop on/off + user mode.'),
      ProbeRequest('CurrentBasalStatusRequest', 'Current basal', 'Active basal rate.'),
      ProbeRequest('CurrentEGVGuiDataRequest', 'CGM (EGV)', 'Current glucose + trend.'),
      ProbeRequest('LastBolusStatusV2Request', 'Last bolus (v2)', 'Most recent bolus.'),
      ProbeRequest('AlertStatusRequest', 'Alerts', 'Active informational alerts.'),
      ProbeRequest('AlarmStatusRequest', 'Alarms', 'Active alarms (higher severity).'),
      ProbeRequest('CGMStatusRequest', 'CGM status', 'Sensor session state.'),
    ]),
    ProbeRequestGroup('Documented opportunities', [
      ProbeRequest('HomeScreenMirrorRequest', 'Home-screen mirror',
          'Exact icons on the pump screen right now.',
          status: ProbeStatus.opportunity),
      ProbeRequest('PumpFeaturesV2Request', 'Pump features (v2)',
          'Enabled features (Dexcom, Control-IQ, BLE control…).',
          status: ProbeStatus.opportunity),
      ProbeRequest('PumpFeaturesV1Request', 'Pump features (v1)',
          'Older feature-flags variant.',
          status: ProbeStatus.opportunity),
      ProbeRequest('PumpGlobalsRequest', 'Pump globals',
          'Quick-bolus config + annunciation settings.',
          status: ProbeStatus.opportunity),
      ProbeRequest('PumpSettingsRequest', 'Pump settings',
          'Auto-shutdown, cannula prime, low-insulin threshold, OLED timeout…',
          status: ProbeStatus.opportunity),
      ProbeRequest('ControlIQSleepScheduleRequest', 'Control-IQ sleep schedule',
          'Sleep-activity start/end/days.',
          status: ProbeStatus.opportunity),
      ProbeRequest('MalfunctionStatusRequest', 'Malfunction status',
          'Pump malfunction state — safety.',
          status: ProbeStatus.opportunity),
      ProbeRequest('CGMHardwareInfoRequest', 'CGM hardware info',
          'Transmitter hardware id.',
          status: ProbeStatus.opportunity),
    ]),
    ProbeRequestGroup('Settings & reminders', [
      ProbeRequest('CurrentActiveIdpValuesRequest', 'Active IDP values',
          'Currently-active profile values.', status: ProbeStatus.experimental),
      ProbeRequest('GlobalMaxBolusSettingsRequest', 'Global max bolus',
          'Configured max-bolus limit.', status: ProbeStatus.experimental),
      ProbeRequest('BasalLimitSettingsRequest', 'Basal limit',
          'Configured basal limit.', status: ProbeStatus.experimental),
      ProbeRequest('ReminderStatusRequest', 'Reminder status',
          'Active reminders state.', status: ProbeStatus.experimental),
      ProbeRequest('RemindersRequest', 'Reminders', 'Configured reminders.',
          status: ProbeStatus.experimental),
      ProbeRequest('LocalizationRequest', 'Localization',
          'Language / units / region config.', status: ProbeStatus.experimental),
    ]),
    ProbeRequestGroup('CGM & Basal-IQ internals', [
      ProbeRequest('CgmStatusV2Request', 'CGM status (v2)', 'Extended sensor state.',
          status: ProbeStatus.experimental),
      ProbeRequest('CGMAlertStatusRequest', 'CGM alert status', 'CGM alert flags.',
          status: ProbeStatus.experimental),
      ProbeRequest('CGMGlucoseAlertSettingsRequest', 'CGM glucose alert settings',
          'High/low alert thresholds.', status: ProbeStatus.experimental),
      ProbeRequest('CGMRateAlertSettingsRequest', 'CGM rate alert settings',
          'Rise/fall alert config.', status: ProbeStatus.experimental),
      ProbeRequest('CGMOORAlertSettingsRequest', 'CGM out-of-range alerts',
          'OOR alert config.', status: ProbeStatus.experimental),
      ProbeRequest('LastBGRequest', 'Last BG', 'Last blood-glucose value.',
          status: ProbeStatus.experimental),
      ProbeRequest('BasalIQStatusRequest', 'Basal-IQ status', 'Basal-IQ state.',
          status: ProbeStatus.experimental),
      ProbeRequest('BasalIQSettingsRequest', 'Basal-IQ settings', 'Basal-IQ config.',
          status: ProbeStatus.experimental),
      ProbeRequest('BasalIQAlertInfoRequest', 'Basal-IQ alert info', 'Basal-IQ alerts.',
          status: ProbeStatus.experimental),
      ProbeRequest('CgmSupportPackageStatusRequest', 'CGM support package',
          'Diagnostic support-package state.', status: ProbeStatus.experimental),
      ProbeRequest('GetG6TransmitterHardwareInfoRequest', 'G6 transmitter HW',
          'Dexcom G6 transmitter info.', status: ProbeStatus.experimental),
      ProbeRequest('GetSavedG7PairingCodeRequest', 'Saved G7 pairing code',
          'Stored Dexcom G7 pairing code.', status: ProbeStatus.experimental),
    ]),
    ProbeRequestGroup('Software / diagnostics', [
      ProbeRequest('CommonSoftwareInfoRequest', 'Common software info',
          'Shared SW build info.', status: ProbeStatus.experimental),
      ProbeRequest('BleSoftwareInfoRequest', 'BLE software info',
          'BLE stack build info.', status: ProbeStatus.experimental),
      ProbeRequest('PumpVersionBRequest', 'Pump version (B)',
          'Alternate version block.', status: ProbeStatus.experimental),
      ProbeRequest('LoadStatusRequest', 'Load status', 'Pump load state.',
          status: ProbeStatus.experimental),
      ProbeRequest('StreamDataReadinessRequest', 'Stream data readiness',
          'Whether streaming characteristics are ready.',
          status: ProbeStatus.experimental),
      ProbeRequest('HistoryLogStatusRequest', 'History-log status',
          'First/last sequence numbers.', status: ProbeStatus.experimental),
    ]),
    ProbeRequestGroup('Unknown / experimental (discover)', [
      ProbeRequest('SecretMenuRequest', 'Secret menu',
          'Undocumented service-menu read — dump and decode.',
          status: ProbeStatus.experimental),
      ProbeRequest('UnknownMobiOpcode110Request', 'Unknown Mobi opcode 110',
          'Reverse-engineered-but-unnamed read.', status: ProbeStatus.experimental),
      ProbeRequest('ActiveAamBitsRequest', 'Active AAM bits',
          'Automatic-mode bitfield.', status: ProbeStatus.experimental),
      ProbeRequest('HighestAamRequest', 'Highest AAM', 'Highest automatic-mode value.',
          status: ProbeStatus.experimental),
      ProbeRequest('BolusCalcDataSnapshotRequest', 'Bolus-calc snapshot',
          'Bolus calculator input snapshot (read).', status: ProbeStatus.experimental),
      ProbeRequest('IDPSegmentRequest', 'IDP segment (idp, seg)',
          'One therapy-profile segment.',
          status: ProbeStatus.experimental, params: ['idpId', 'segment']),
      ProbeRequest('HistoryLogRequest', 'History-log range (start, count)',
          'Stream historical events.',
          status: ProbeStatus.experimental, params: ['startSeq', 'count']),
    ]),
  ];
}

class ProbeRequestGroup {
  const ProbeRequestGroup(this.title, this.requests);
  final String title;
  final List<ProbeRequest> requests;
}

extension ProbeCatalogFlat on ProbeCatalog {
  /// Every non-parametric read in the catalog, de-duplicated by class name — the set a
  /// "Sweep all" fires (parametric reads are skipped: they need explicit args).
  static List<ProbeRequest> get sweepable {
    final seen = <String>{};
    final out = <ProbeRequest>[];
    for (final g in ProbeCatalog.groups) {
      for (final r in g.requests) {
        if (r.parametric) continue;
        if (seen.add(r.className)) out.add(r);
      }
    }
    return out;
  }
}
