/// Abstraction over the pump data feed so the app can run against either the real
/// native bridge ([PumpClient]) or the in-app simulator ([SimulatedPumpClient], dev
/// mode) without any UI change. Both expose the same streams + read-only commands.
library;

import 'pump_snapshot.dart';

abstract interface class PumpSource {
  Stream<PumpConnection> get connection;
  Stream<PumpSnapshot> get snapshots;
  Stream<String> get pairingRequests;
  Stream<String> get errors;

  /// Emits the pump's therapy profile (IDP) as JSON when read from the pump.
  Stream<String> get therapyProfiles;

  PumpConnection get lastConnection;
  PumpSnapshot? get lastSnapshot;

  void start();
  Future<void> dispose();

  Future<void> startScan({String? macFilter});
  Future<void> stopScan();
  Future<void> requestStatus();
  Future<void> submitPairingCode(String code, {required bool long});
  Future<void> unpair();
}
