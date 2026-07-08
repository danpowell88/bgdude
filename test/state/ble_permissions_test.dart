/// Below API 31, BLE scanning legally requires runtime ACCESS_FINE_LOCATION
/// (the split bluetoothScan/bluetoothConnect permissions don't exist pre-31 and are
/// auto-granted no-ops) -- pump discovery was silently broken on API 29/30 because
/// the app never requested it. Pins the SDK-gated decision (the actual bug/fix);
/// requestBlePermissions()'s permission_handler call-through isn't exercised here.
library;

import 'package:bgdude/state/ble_permissions.dart';
import 'package:flutter/material.dart';
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

  // TASK-271: bleDeniedSnackBar builds plain Widget objects (Text/SnackBarAction),
  // which are inspectable as ordinary Dart objects without a widget tree/device --
  // no testWidgets() or BuildContext needed to check content/action.
  group('bleDeniedSnackBar', () {
    BlePermissionResult result({
      bool granted = false,
      BlePermissionRequirement requirement =
          BlePermissionRequirement.locationWhenInUse,
      bool locationServicesOff = false,
      bool permanentlyDenied = false,
    }) =>
        (
          granted: granted,
          requirement: requirement,
          locationServicesOff: locationServicesOff,
          permanentlyDenied: permanentlyDenied,
        );

    String textOf(SnackBar s) => (s.content as Text).data!;

    test('a plain denial shows the requirement-specific message with no action', () {
      final snack = bleDeniedSnackBar(result());

      expect(textOf(snack), blePermissionDeniedMessage(
          BlePermissionRequirement.locationWhenInUse));
      expect(snack.action, isNull);
    });

    test(
        'Location services being off shows the distinct message, not the '
        'permission-denied one', () {
      final snack = bleDeniedSnackBar(result(locationServicesOff: true));

      expect(textOf(snack), blePermissionLocationServicesOffMessage);
      expect(
          textOf(snack),
          isNot(contains('permission')),
          reason: 'this is a services-off problem, not a permission denial -- '
              'the wording must not conflate the two',
      );
      expect(snack.action, isNull,
          reason: 'no direct system deep-link exists for the Location toggle');
    });

    test('a permanent denial offers an Open settings action', () {
      final snack = bleDeniedSnackBar(result(permanentlyDenied: true));

      expect(snack.action, isNotNull);
      expect(snack.action!.label, 'Open settings');
    });

    test('locationServicesOff takes priority over permanentlyDenied wording', () {
      // Not a state requestBlePermissions can actually produce (services-off
      // short-circuits before any .request() call that could report permanent
      // denial), but bleDeniedSnackBar's own branch order is worth pinning: the
      // services-off message must win, not silently drop to the denial message.
      final snack =
          bleDeniedSnackBar(result(locationServicesOff: true, permanentlyDenied: true));

      expect(textOf(snack), blePermissionLocationServicesOffMessage);
    });
  });
}
