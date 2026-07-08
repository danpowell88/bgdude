/// Below API 31, BLE scanning legally requires runtime ACCESS_FINE_LOCATION
/// (the split bluetoothScan/bluetoothConnect permissions don't exist pre-31 and are
/// auto-granted no-ops) -- pump discovery was silently broken on API 29/30 because
/// the app never requested it. Pins the SDK-gated decision (the actual bug/fix);
/// requestBlePermissions()'s permission_handler call-through isn't exercised here.
library;

import 'package:bgdude/state/ble_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('blePermissionRequirementFor', () {
    test('below API 31 needs locationWhenInUse', () {
      expect(blePermissionRequirementFor(29),
          BlePermissionRequirement.locationWhenInUse);
      expect(blePermissionRequirementFor(30),
          BlePermissionRequirement.locationWhenInUse);
    });

    test('API 31 and above needs the split Bluetooth permissions', () {
      expect(blePermissionRequirementFor(31),
          BlePermissionRequirement.splitBluetoothPermissions);
      expect(blePermissionRequirementFor(34),
          BlePermissionRequirement.splitBluetoothPermissions);
    });
  });

  group('blePermissionDeniedMessage', () {
    test('mentions location for the pre-31 requirement', () {
      expect(
          blePermissionDeniedMessage(BlePermissionRequirement.locationWhenInUse),
          contains('Location'));
    });

    test('mentions Bluetooth for the split-permission requirement', () {
      expect(
          blePermissionDeniedMessage(
              BlePermissionRequirement.splitBluetoothPermissions),
          contains('Bluetooth'));
    });
  });
}
