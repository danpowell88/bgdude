/// BLE transport abstraction for a standard Bluetooth Glucose Service (0x1808) meter.
///
/// The real implementation ([FbpGlucoseMeterTransport] in `_fbp.dart`) drives
/// flutter_blue_plus; this interface keeps the sync/orchestration logic and its tests free
/// of the BLE dependency and of hardware.
library;

import 'glucose_meter.dart';

/// A discovered / paired meter.
class MeterDevice {
  const MeterDevice({required this.id, required this.name});

  /// BLE identifier (Android: the MAC-like remote id) — stable across sessions once bonded.
  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  static MeterDevice fromJson(Map<String, dynamic> j) => MeterDevice(
        id: j['id'] as String,
        name: (j['name'] as String?)?.trim().isNotEmpty == true
            ? j['name'] as String
            : 'Glucose meter',
      );
}

abstract interface class GlucoseMeterTransport {
  /// Whether BLE is usable on this device right now (adapter present + on). When false the
  /// UI shows guidance instead of a scan.
  Future<bool> isAvailable();

  /// Scan for meters advertising the Glucose Service. Emits each device once; completes
  /// (or is cancelled by [stopScan]) after [timeout].
  Stream<MeterDevice> scan({Duration timeout});

  Future<void> stopScan();

  /// Connect + bond to [deviceId], enable Glucose Measurement notifications and RACP
  /// indications, request stored records (only those with sequence number > [sinceSeq]
  /// when given, else all), parse them, then disconnect. Ordered oldest→newest.
  Future<List<GlucoseMeterReading>> fetchRecords(String deviceId, {int? sinceSeq});
}
