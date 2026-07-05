/// Dart model of the pump status snapshot streamed from the native bridge over the
/// `bgdude/pump_events` EventChannel. Mirrors `MutableSnapshot.toJson()` on the Kotlin
/// side.
library;

import '../core/samples.dart';

enum PumpConnectionStage {
  idle,
  scanning,
  discovered,
  bonding,
  awaitingPairingCode,
  jpakeInProgress,
  authenticated,
  connected,
  disconnected,
  error,
}

PumpConnectionStage _stageFromName(String? name) {
  switch (name) {
    case 'IDLE':
      return PumpConnectionStage.idle;
    case 'SCANNING':
      return PumpConnectionStage.scanning;
    case 'DISCOVERED':
      return PumpConnectionStage.discovered;
    case 'BONDING':
      return PumpConnectionStage.bonding;
    case 'AWAITING_PAIRING_CODE':
      return PumpConnectionStage.awaitingPairingCode;
    case 'JPAKE_IN_PROGRESS':
      return PumpConnectionStage.jpakeInProgress;
    case 'AUTHENTICATED':
      return PumpConnectionStage.authenticated;
    case 'CONNECTED':
      return PumpConnectionStage.connected;
    case 'DISCONNECTED':
      return PumpConnectionStage.disconnected;
    default:
      return PumpConnectionStage.error;
  }
}

class PumpConnection {
  const PumpConnection({
    required this.stage,
    this.pumpName,
    this.jpakeProgress,
    this.error,
  });

  final PumpConnectionStage stage;
  final String? pumpName;
  final int? jpakeProgress;
  final String? error;

  bool get isConnected => stage == PumpConnectionStage.connected;

  static PumpConnection fromEvent(Map<Object?, Object?> e) => PumpConnection(
        stage: _stageFromName(e['stage'] as String?),
        pumpName: e['pumpName'] as String?,
        jpakeProgress: (e['jpakeProgress'] as num?)?.toInt(),
        error: e['error'] as String?,
      );

  static const PumpConnection idle = PumpConnection(stage: PumpConnectionStage.idle);
}

class PumpSnapshot {
  const PumpSnapshot({
    required this.time,
    this.batteryPercent,
    this.isCharging,
    this.reservoirUnits,
    this.iobUnits,
    this.basalUnitsPerHour,
    this.controlIqActive,
    this.cgmMgdl,
    this.cgmTrend,
    this.cgmTime,
    this.lastBolusUnits,
    this.lastBolusTime,
    this.apiVersion,
    this.firmwareVersion,
    this.activeAlerts = const [],
    this.activeAlarms = const [],
  });

  final DateTime time;
  final int? batteryPercent;

  /// Whether the pump is charging (V2 battery response only; null on V1 / unknown).
  final bool? isCharging;
  final double? reservoirUnits;
  final double? iobUnits;
  final double? basalUnitsPerHour;
  final bool? controlIqActive;
  final int? cgmMgdl;
  final GlucoseTrend? cgmTrend;
  final DateTime? cgmTime;
  final double? lastBolusUnits;
  final DateTime? lastBolusTime;
  final String? apiVersion;
  final String? firmwareVersion;

  /// Active pump alerts (informational) and alarms (higher severity), by name.
  final List<String> activeAlerts;
  final List<String> activeAlarms;

  static GlucoseTrend _trend(String? s) => switch (s) {
        'doubleUp' => GlucoseTrend.doubleUp,
        'singleUp' => GlucoseTrend.singleUp,
        'fortyFiveUp' => GlucoseTrend.fortyFiveUp,
        'flat' => GlucoseTrend.flat,
        'fortyFiveDown' => GlucoseTrend.fortyFiveDown,
        'singleDown' => GlucoseTrend.singleDown,
        'doubleDown' => GlucoseTrend.doubleDown,
        _ => GlucoseTrend.unknown,
      };

  static DateTime? _time(num? epochMs) =>
      epochMs == null ? null : DateTime.fromMillisecondsSinceEpoch(epochMs.toInt());

  static PumpSnapshot fromJson(Map<String, dynamic> j) => PumpSnapshot(
        time: _time(j['timestampEpochMs'] as num?) ?? DateTime.now(),
        batteryPercent: (j['batteryPercent'] as num?)?.toInt(),
        isCharging: j['isCharging'] as bool?,
        reservoirUnits: (j['reservoirUnits'] as num?)?.toDouble(),
        iobUnits: (j['iobUnits'] as num?)?.toDouble(),
        basalUnitsPerHour: (j['basalUnitsPerHour'] as num?)?.toDouble(),
        controlIqActive: j['controlIqActive'] as bool?,
        cgmMgdl: (j['cgmMgdl'] as num?)?.toInt(),
        cgmTrend: _trend(j['cgmTrend'] as String?),
        cgmTime: _time(j['cgmTimestampEpochMs'] as num?),
        lastBolusUnits: (j['lastBolusUnits'] as num?)?.toDouble(),
        lastBolusTime: _time(j['lastBolusTimestampEpochMs'] as num?),
        apiVersion: j['apiVersion'] as String?,
        firmwareVersion: j['firmwareVersion'] as String?,
        activeAlerts: _stringList(j['activeAlerts']),
        activeAlarms: _stringList(j['activeAlarms']),
      );

  static List<String> _stringList(Object? v) =>
      v is List ? [for (final e in v) e.toString()] : const [];

  /// Convert the current CGM reading to a domain sample, if present.
  CgmSample? toCgmSample() {
    final mgdl = cgmMgdl;
    if (mgdl == null || cgmTime == null) return null;
    return CgmSample(
        time: cgmTime!, mgdl: mgdl.toDouble(), trend: cgmTrend ?? GlucoseTrend.unknown);
  }
}
