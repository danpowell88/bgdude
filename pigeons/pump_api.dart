// Pigeon interface definition for the native pumpx2 bridge.
//
// Generate with:
//   dart run pigeon --input pigeons/pump_api.dart
//
// This defines a deliberately NARROW, read-only surface over pumpx2. There is no
// method here that writes to the pump's control characteristic — the native side
// physically cannot deliver insulin. Commands flow Flutter→host; continuous pump
// state flows host→Flutter via the separate EventChannel `bgdude/pump_events`
// (see lib/pump/pump_event_channel.dart), because Pigeon's flutter-callback API is
// better suited to request/response than a high-rate stream.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/pump/pigeon/pump_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/bgdude/app/pump/PumpApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.bgdude.app.pump'),
    dartPackageName: 'bgdude',
  ),
)
enum PumpModel { tslimX2, mobi, unknown }

enum PairingCodeType { short6Char, long16Char }

enum ConnectionStage {
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

class PumpConnectionState {
  PumpConnectionState({
    required this.stage,
    required this.model,
    this.pumpName,
    this.macAddress,
    this.jpakeProgress,
    this.errorMessage,
  });

  ConnectionStage stage;
  PumpModel model;
  String? pumpName;
  String? macAddress;
  int? jpakeProgress; // 0..N steps
  String? errorMessage;
}

/// Snapshot of the pump's current status, marshalled from pumpx2 response objects.
/// All glucose is mg/dL; insulin in units.
class PumpStatusSnapshot {
  PumpStatusSnapshot({
    required this.timestampEpochMs,
    this.batteryPercent,
    this.reservoirUnits,
    this.iobUnits,
    this.basalUnitsPerHour,
    this.controlIqActive,
    this.cgmMgdl,
    this.cgmTrend,
    this.cgmTimestampEpochMs,
    this.lastBolusUnits,
    this.lastBolusTimestampEpochMs,
    this.apiVersion,
    this.firmwareVersion,
    this.activeAlerts,
  });

  int timestampEpochMs;
  int? batteryPercent;
  double? reservoirUnits;
  double? iobUnits;
  double? basalUnitsPerHour;
  bool? controlIqActive;
  int? cgmMgdl;
  String? cgmTrend; // maps to GlucoseTrend on the Dart side
  int? cgmTimestampEpochMs;
  double? lastBolusUnits;
  int? lastBolusTimestampEpochMs;
  String? apiVersion;
  String? firmwareVersion;
  List<String?>? activeAlerts;
}

/// A decoded history-log entry (bolus/basal/carb/alarm), best-effort — pumpx2's history
/// decoding is partial, so `raw` carries anything we couldn't type.
class HistoryLogEntry {
  HistoryLogEntry({
    required this.epochMs,
    required this.type,
    this.units,
    this.carbsGrams,
    this.mgdl,
    this.raw,
  });

  int epochMs;
  String type; // 'bolus' | 'basalChange' | 'carb' | 'alarm' | 'cgm' | 'unknown'
  double? units;
  double? carbsGrams;
  int? mgdl;
  String? raw;
}

/// Host API: commands invoked from Flutter. All read-only.
@HostApi()
abstract class PumpHostApi {
  /// Ensure the foreground service is running and BLE is ready.
  @async
  void startService();

  @async
  void stopService();

  /// Begin scanning for a pump; optionally filter to a known MAC.
  @async
  void startScan({String? macFilter});

  @async
  void stopScan();

  /// Provide the pairing code shown on the pump when `awaitingPairingCode`.
  @async
  void submitPairingCode(String code, PairingCodeType type);

  /// Request a fresh full status snapshot (bust cache).
  @async
  PumpStatusSnapshot requestStatus();

  /// Fetch decoded history-log entries in a time window (best-effort).
  @async
  List<HistoryLogEntry> fetchHistory(int fromEpochMs, int toEpochMs);

  /// Current connection state (also pushed via the event channel).
  PumpConnectionState currentConnectionState();

  /// Forget the paired pump and clear stored secrets.
  @async
  void unpair();
}

/// Flutter API: callbacks the host can invoke for one-shot events. Continuous status
/// streaming uses the EventChannel instead (higher throughput, back-pressure friendly).
@FlutterApi()
abstract class PumpFlutterApi {
  void onConnectionStateChanged(PumpConnectionState state);
  void onPairingCodeRequired(PairingCodeType type);
  void onCriticalError(String message);
}
