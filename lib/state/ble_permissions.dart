/// SDK-gated BLE scanning permission (TASK-226).
///
/// Below API 31, the split `bluetoothScan`/`bluetoothConnect` runtime permissions
/// don't exist — Android auto-grants them as no-ops — but a BLE scan on those OS
/// versions legally requires `ACCESS_FINE_LOCATION` at runtime (the manifest already
/// declares it with `maxSdkVersion="30"`). Without requesting it, pump discovery is
/// silently broken on API 29/30 even though the app looks like it has "permission".
library;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
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

/// [requestBlePermissions]'s result shape, named so the two UI call sites
/// (onboarding, Settings' "Re-pair pump") and [bleDeniedSnackBar] share one type.
typedef BlePermissionResult = ({
  bool granted,
  BlePermissionRequirement requirement,
  bool locationServicesOff,
  bool permanentlyDenied,
});

/// Request whatever permission(s) this device's Android version needs to scan for
/// and connect to the pump over BLE. [requirement] tells the caller which rationale
/// applies if [granted] is false.
///
/// TASK-271: two failure modes [granted] alone can't distinguish, both of which used
/// to leave pump discovery silently broken:
///  * [locationServicesOff] — below API 31 a BLE scan legally needs BOTH fine
///    location GRANTED and the system Location master toggle ON. A user can grant
///    the permission with Location itself still off (Android 11 in particular),
///    and startScan() then returns zero results with no signal why.
///  * [permanentlyDenied] — a "don't ask again" denial makes every future
///    `.request()` silently resolve denied again with no OS dialog at all; the only
///    way forward is [openAppSettings] from `package:permission_handler`.
Future<BlePermissionResult> requestBlePermissions(
    {DeviceInfoPlugin? deviceInfo}) async {
  final info = deviceInfo ?? DeviceInfoPlugin();
  final sdkInt = (await info.androidInfo).version.sdkInt;
  final requirement = blePermissionRequirementFor(sdkInt);

  if (requirement == BlePermissionRequirement.locationWhenInUse &&
      await Permission.location.serviceStatus.isDisabled) {
    return (
      granted: false,
      requirement: requirement,
      locationServicesOff: true,
      permanentlyDenied: false,
    );
  }

  final statuses = switch (requirement) {
    BlePermissionRequirement.splitBluetoothPermissions =>
      (await [Permission.bluetoothConnect, Permission.bluetoothScan].request())
          .values,
    BlePermissionRequirement.locationWhenInUse =>
      [await Permission.locationWhenInUse.request()],
  };
  return (
    granted: statuses.every((s) => s.isGranted),
    requirement: requirement,
    locationServicesOff: false,
    permanentlyDenied: statuses.any((s) => s.isPermanentlyDenied),
  );
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

/// TASK-271: distinct from a permission DENIAL — the permission is granted, but the
/// system Location master toggle itself is off, which a pre-31 BLE scan also needs.
const String blePermissionLocationServicesOffMessage =
    'Location is turned off on this phone. Bluetooth scanning on this version of '
    'Android needs it switched on — enable Location in system settings, then try '
    'again.';

/// TASK-271: the SnackBar for a failed [requestBlePermissions] call, shared by both
/// UI call sites (onboarding's "Get connected" step and Settings' "Re-pair pump") so
/// the three failure modes read consistently everywhere: a plain denial (repeatable
/// via the OS dialog next time), Location services being off (distinct wording, no
/// direct system deep-link exists for the Location toggle), and a permanent denial
/// (an "Open settings" action, since a repeated `.request()` can never succeed again
/// on its own — see [permanentlyDenied]'s doc on why).
SnackBar bleDeniedSnackBar(BlePermissionResult ble) {
  if (ble.locationServicesOff) {
    return const SnackBar(content: Text(blePermissionLocationServicesOffMessage));
  }
  return SnackBar(
    content: Text(blePermissionDeniedMessage(ble.requirement)),
    action: ble.permanentlyDenied
        ? const SnackBarAction(label: 'Open settings', onPressed: openAppSettings)
        : null,
  );
}
