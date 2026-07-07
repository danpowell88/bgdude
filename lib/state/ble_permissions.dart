/// SDK-gated BLE scanning permission (TASK-226).
///
/// Below API 31, the split `bluetoothScan`/`bluetoothConnect` runtime permissions
/// don't exist — Android auto-grants them as no-ops — but a BLE scan on those OS
/// versions legally requires `ACCESS_FINE_LOCATION` at runtime (the manifest already
/// declares it with `maxSdkVersion="30"`). Without requesting it, pump discovery is
/// silently broken on API 29/30 even though the app looks like it has "permission".
library;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Which permission(s) this Android SDK level needs to scan for the pump over BLE.
/// Pure — unit-testable without touching the platform channel.
enum BlePermissionRequirement {
  /// API 31+: the split bluetoothScan/bluetoothConnect runtime permissions.
  splitBluetoothPermissions,

  /// API < 31: BLE scanning legally requires fine location at runtime.
  locationWhenInUse,
}

BlePermissionRequirement blePermissionRequirementFor(int androidSdkInt) =>
    androidSdkInt >= 31
        ? BlePermissionRequirement.splitBluetoothPermissions
        : BlePermissionRequirement.locationWhenInUse;

/// Request whatever permission(s) this device's Android version needs to scan for
/// and connect to the pump over BLE. [requirement] tells the caller which rationale
/// applies if [granted] is false.
Future<({bool granted, BlePermissionRequirement requirement})>
    requestBlePermissions({DeviceInfoPlugin? deviceInfo}) async {
  final info = deviceInfo ?? DeviceInfoPlugin();
  final sdkInt = (await info.androidInfo).version.sdkInt;
  final requirement = blePermissionRequirementFor(sdkInt);
  final granted = switch (requirement) {
    BlePermissionRequirement.splitBluetoothPermissions => (await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request())
        .values
        .every((s) => s.isGranted),
    BlePermissionRequirement.locationWhenInUse =>
      (await Permission.locationWhenInUse.request()).isGranted,
  };
  return (granted: granted, requirement: requirement);
}

/// User-facing rationale for a denied BLE permission, worded for whichever
/// requirement this SDK level actually needed.
String blePermissionDeniedMessage(BlePermissionRequirement requirement) =>
    switch (requirement) {
      BlePermissionRequirement.splitBluetoothPermissions =>
        'Bluetooth permission is needed to scan for your pump — enable it for '
            'bgdude in system settings.',
      BlePermissionRequirement.locationWhenInUse =>
        'Location permission is needed to scan for Bluetooth devices on this '
            'version of Android — enable it for bgdude in system settings.',
    };
