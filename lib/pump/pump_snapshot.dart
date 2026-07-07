/// Dart model of the pump status snapshot streamed from the native bridge over the
/// `bgdude/pump_events` EventChannel. Mirrors `MutableSnapshot.toJson()` on the Kotlin
/// side.
library;

import '../analytics/predictor.dart';
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
    this.schemaVersion,
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

  /// Wire-format version the native side emitted (null on locally-constructed
  /// snapshots and pre-versioned payloads). See [expectedSchemaVersion].
  final int? schemaVersion;

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

  /// TASK-250: a battery percentage is physically 0–100; a hostile/torn payload
  /// (e.g. -81) must not flow through to the UI/alerts unchecked. Null passes through
  /// (absence of data, not garbage).
  static int? _clampPercent(int? v) => v?.clamp(0, 100);

  /// TASK-250: reservoir/IOB units are physically non-negative and, for a t:slim X2,
  /// nowhere near astronomically large (a hostile 1.79e308 is the motivating example)
  /// — clamp to a generously wide but sane band. NaN (from a garbled double) is
  /// treated the same as absent data rather than propagating a value that compares
  /// false to everything downstream.
  static double? _clampNonNegative(double? v, {double max = 1000}) =>
      v == null || v.isNaN ? null : v.clamp(0, max);

  /// TASK-273: unlike battery/reservoir/IOB above (TASK-250) — where clamping toward
  /// 0 only ever makes the reading MORE alarming, never less, so a clamped garbage
  /// value is still a safe fallback — a corrupt glucose reading or dosing field must
  /// NOT be clamped into a plausible-looking number: clamping -81 mg/dL to 39 would
  /// show a fake LOW the user might act on (rescue carbs, calling for help) for a
  /// reading that never happened. Reject out-of-range values to null ("no reading"),
  /// never a fabricated in-range one. Bounds: glucose 20–600 mg/dL matches the
  /// existing sanity band in analytics/metrics.dart; dosing bounds match the t:slim
  /// X2's real hardware limits (max bolus 25 U, max basal 15 U/hr).
  static int? _rejectOutOfRangeInt(int? v, {required int min, required int max}) =>
      v == null || v < min || v > max ? null : v;

  static double? _rejectOutOfRangeDouble(double? v,
          {required double min, required double max}) =>
      v == null || v.isNaN || v < min || v > max ? null : v;

  /// TASK-120: wire-format version expected from the Kotlin side
  /// (MutableSnapshot.SCHEMA_VERSION). Evolution policy is ADDITIVE-ONLY: new
  /// fields may be appended (this parser ignores unknowns); renaming, retyping
  /// or removing a field requires bumping the version and updating the golden
  /// fixture + both contract tests.
  static const int expectedSchemaVersion = 1;

  static PumpSnapshot fromJson(Map<String, dynamic> j) => PumpSnapshot(
        schemaVersion: (j['schemaVersion'] as num?)?.toInt(),
        time: _time(j['timestampEpochMs'] as num?) ?? DateTime.now(),
        // TASK-250: the native side is trusted, but a hostile/corrupt payload (e.g. a
        // torn platform-channel message) must not turn into a physically-impossible
        // reading flowing unchecked into the rest of the app -- clamp to the
        // physically sane range rather than pass through raw.
        batteryPercent: _clampPercent((j['batteryPercent'] as num?)?.toInt()),
        isCharging: j['isCharging'] as bool?,
        reservoirUnits: _clampNonNegative((j['reservoirUnits'] as num?)?.toDouble()),
        iobUnits: _clampNonNegative((j['iobUnits'] as num?)?.toDouble()),
        basalUnitsPerHour: _rejectOutOfRangeDouble(
            (j['basalUnitsPerHour'] as num?)?.toDouble(), min: 0, max: 15),
        maxBolusUnits: _rejectOutOfRangeDouble(
            (j['maxBolusUnits'] as num?)?.toDouble(), min: 0, max: 25),
        maxBasalUnitsPerHour: _rejectOutOfRangeDouble(
            (j['maxBasalUnitsPerHour'] as num?)?.toDouble(), min: 0, max: 15),
        controlIqActive: j['controlIqActive'] as bool?,
        closedLoopEnabled: j['closedLoopEnabled'] as bool?,
        controlIqMode: ControlIqMode.fromName(j['controlIqMode'] as String?),
        cgmMgdl: _rejectOutOfRangeInt((j['cgmMgdl'] as num?)?.toInt(),
            min: 20, max: 600),
        cgmTrend: _trend(j['cgmTrend'] as String?),
        cgmTime: _time(j['cgmTimestampEpochMs'] as num?),
        lastBolusUnits: _rejectOutOfRangeDouble(
            (j['lastBolusUnits'] as num?)?.toDouble(), min: 0, max: 25),
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

  /// Map this snapshot's Control-IQ status onto the closed-loop model the
  /// predictor/advisor use (TASK-126). Delegates to [mapControlIqState] (a static
  /// so callers holding just the three raw fields — e.g. a `.select()`-destructured
  /// record, to avoid rebuilding on unrelated snapshot changes — can call it too).
  ControlIqState get controlIqState => mapControlIqState(
      enabled: closedLoopEnabled, active: controlIqActive, mode: controlIqMode);

  /// Off unless the loop is actually enabled. `enabled` (closedLoopEnabled) is
  /// preferred; `active` (controlIqActive) is the fallback for older firmware that
  /// doesn't report the former.
  static ControlIqState mapControlIqState({
    required bool? enabled,
    required bool? active,
    required ControlIqMode? mode,
  }) {
    final on = enabled ?? active ?? false;
    if (!on) return ControlIqState.off;
    return switch (mode) {
      ControlIqMode.sleep => ControlIqState.sleep,
      ControlIqMode.exercise => ControlIqState.exercise,
      // Standard, or unknown-but-active firmware → treat as Standard.
      _ => ControlIqState.standard,
    };
  }
}
