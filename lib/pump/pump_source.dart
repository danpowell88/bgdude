/// Abstraction over the pump data feed so the app can run against either the real
/// native bridge ([PumpClient]) or the in-app simulator ([SimulatedPumpClient], dev
/// mode) without any UI change. Both expose the same streams + read-only commands.
library;

import 'probe_event.dart';
import 'pump_snapshot.dart';

abstract interface class PumpSource {
  Stream<PumpConnection> get connection;
  Stream<PumpSnapshot> get snapshots;
  Stream<String> get pairingRequests;
  Stream<String> get errors;

  /// Emits the pump's therapy profile (IDP) as JSON when read from the pump.
  Stream<String> get therapyProfiles;

  /// Protocol Explorer: raw messages (sent requests / received responses) captured while
  /// [setProbeCapture] is enabled.
  Stream<ProbeEvent> get probeEvents;

  PumpConnection get lastConnection;
  PumpSnapshot? get lastSnapshot;

  void start();
  Future<void> dispose();

  Future<void> startScan({String? macFilter});
  Future<void> stopScan();
  Future<void> requestStatus();
  Future<void> submitPairingCode(String code, {required bool long});
  Future<void> unpair();

  /// Turn the probe firehose on/off (only while the explorer screen is open).
  Future<void> setProbeCapture(bool enabled);

  /// Fire one read-only `currentStatus` request by pumpx2 class name. Returns null on
  /// success, or a human-readable refusal reason (the native layer safety-gates every send).
  Future<String?> sendProbe(String className, {int? arg1, int? arg2});

  /// Fetch decoded history-log entries in the epoch-ms window (read-only backfill). Routed
  /// through the source so a non-hardware implementation (the demo/simulator) can intercept
  /// it rather than callers reaching the native command channel directly (TASK-43).
  Future<List<dynamic>> fetchHistory(
      {required int fromEpochMs, required int toEpochMs});
}
