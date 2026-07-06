/// Dart model of the pump status snapshot streamed from the native bridge over the
/// `bgdude/pump_events` EventChannel. Mirrors `MutableSnapshot.toJson()` on the Kotlin
/// side.
library;

import '../core/samples.dart';

/// The Control-IQ user mode reported by the pump. Control-IQ steers glucose toward a
/// different target band per mode and (in standard/exercise) delivers automatic
/// correction boluses; sleep mode is basal-only with a tighter target.
enum ControlIqMode {
  standard,
  sleep,
  exercise,
  unknown;

  static ControlIqMode fromName(String? s) => switch (s) {
        'STANDARD' => ControlIqMode.standard,
        'SLEEP' => ControlIqMode.sleep,
        'EXERCISE' => ControlIqMode.exercise,
        _ => ControlIqMode.unknown,
      };

  String get label => switch (this) {
        ControlIqMode.standard => 'Standard',
        ControlIqMode.sleep => 'Sleep',
        ControlIqMode.exercise => 'Exercise',
        ControlIqMode.unknown => 'Unknown',
      };
}

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
    this.maxBolusUnits,
    this.maxBasalUnitsPerHour,
    this.controlIqActive,
    this.closedLoopEnabled,
    this.controlIqMode = ControlIqMode.unknown,
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

  /// The pump's own configured maximum single bolus (units), read-only (TASK-72).
  final double? maxBolusUnits;

  /// The pump's configured maximum basal rate (units/hour), read-only (TASK-72).
  final double? maxBasalUnitsPerHour;
  final bool? controlIqActive;

  /// Whether the Control-IQ closed loop is switched on (null on older firmware /
  /// before the first ControlIQInfo response).
  final bool? closedLoopEnabled;

  /// Current Control-IQ user mode (standard / sleep / exercise).
  final ControlIqMode controlIqMode;

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
        maxBolusUnits: (j['maxBolusUnits'] as num?)?.toDouble(),
        maxBasalUnitsPerHour: (j['maxBasalUnitsPerHour'] as num?)?.toDouble(),
        controlIqActive: j['controlIqActive'] as bool?,
        closedLoopEnabled: j['closedLoopEnabled'] as bool?,
        controlIqMode: ControlIqMode.fromName(j['controlIqMode'] as String?),
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
