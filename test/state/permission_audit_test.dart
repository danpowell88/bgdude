/// The permission registry and audit (issue #376).
library;

import 'package:bgdude/state/permission_audit.dart';
import 'package:flutter_test/flutter_test.dart';

AppPermission _byId(String id) =>
    allAppPermissions.firstWhere((p) => p.id == id);

void main() {
  group('registry', () {
    test('every entry says what breaks, not just what it wants', () {
      // The consequence is the half that lets a user decide whether to care.
      for (final p in allAppPermissions) {
        expect(p.whatBreaks, isNotEmpty, reason: p.id);
        expect(p.why, isNotEmpty, reason: p.id);
        expect(p.requestedAt, isNotEmpty, reason: p.id);
      }
    });

    test('ids are unique', () {
      final ids = allAppPermissions.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('background location is not in the registry', () {
      // decision-17: no feature reads position, so we never ask.
      expect(
        allAppPermissions.any((p) => p.id.toLowerCase().contains('background')),
        isFalse,
      );
    });
  });

  group('permissionsForSdk', () {
    test('API 30 needs location for BLE and does not ask for the split '
        'Bluetooth permissions', () {
      final ids = permissionsForSdk(30).map((p) => p.id);
      expect(ids, contains('locationWhenInUse'));
      expect(ids, isNot(contains('bluetoothScan')));
      // POST_NOTIFICATIONS did not exist before 33 — asking would be a no-op.
      expect(ids, isNot(contains('notification')));
    });

    test('API 33+ needs the split Bluetooth permissions and notifications, '
        'not location', () {
      final ids = permissionsForSdk(33).map((p) => p.id);
      expect(ids, contains('bluetoothScan'));
      expect(ids, contains('notification'));
      expect(ids, isNot(contains('locationWhenInUse')));
    });

    test('the API 31 boundary flips both ways at once', () {
      // 30 vs 31 is exactly where the manifest's maxSdkVersion="30" sits; an
      // off-by-one here silently breaks scanning on one Android version.
      expect(permissionsForSdk(30).map((p) => p.id), contains('locationWhenInUse'));
      expect(permissionsForSdk(31).map((p) => p.id),
          isNot(contains('locationWhenInUse')));
      expect(permissionsForSdk(31).map((p) => p.id), contains('bluetoothScan'));
    });

    test('version-independent permissions apply on every SDK', () {
      for (final sdk in [29, 31, 33, 36]) {
        expect(permissionsForSdk(sdk).map((p) => p.id),
            contains('ignoreBatteryOptimizations'),
            reason: 'sdk $sdk');
      }
    });

    test('minSdk 29 still produces a usable set', () {
      expect(permissionsForSdk(29), isNotEmpty);
    });
  });

  group('auditPermissions / criticalGaps', () {
    Future<PermissionGrant> probeAll(PermissionGrant g) => Future.value(g);

    test('audits every applicable permission', () async {
      final audit = await auditPermissions(33, (_) => probeAll(PermissionGrant.granted));
      expect(audit.length, permissionsForSdk(33).length);
      expect(hasCriticalGap(audit), isFalse);
    });

    test('a denied critical permission is a gap', () async {
      final audit = await auditPermissions(
        33,
        (id) => probeAll(id == 'notification'
            ? PermissionGrant.denied
            : PermissionGrant.granted),
      );
      expect(criticalGaps(audit).map((a) => a.permission.id), ['notification']);
    });

    test('a denied OPTIONAL permission is not a gap', () async {
      // Camera off must not raise the same alarm as notifications off; if it did,
      // the banner would be permanently on and stop meaning anything.
      final audit = await auditPermissions(
        33,
        (id) => probeAll(
            id == 'camera' ? PermissionGrant.denied : PermissionGrant.granted),
      );
      expect(hasCriticalGap(audit), isFalse);
      expect(_byId('camera').severity, PermissionSeverity.optional);
    });

    test('permanently denied counts as a gap', () async {
      final audit = await auditPermissions(
        33,
        (id) => probeAll(id == 'ignoreBatteryOptimizations'
            ? PermissionGrant.permanentlyDenied
            : PermissionGrant.granted),
      );
      expect(criticalGaps(audit).map((a) => a.permission.id),
          ['ignoreBatteryOptimizations']);
    });

    test('unknown is NOT reported as a gap', () async {
      // An unreadable status is not evidence of denial. Health Connect always reads
      // unknown through permission_handler; treating that as failure would leave a
      // permanent false warning and train the user to ignore real ones.
      final audit =
          await auditPermissions(33, (_) => probeAll(PermissionGrant.unknown));
      expect(hasCriticalGap(audit), isFalse);
    });
  });
}
