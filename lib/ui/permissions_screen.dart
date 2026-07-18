/// The one place that shows every permission bgdude needs, its live state, and what
/// breaks without it (issue #376).
///
/// Before this, permissions were requested in three places (onboarding, Settings, the
/// BLE re-pair flow) and there was nowhere to answer "is anything missing?" — which is
/// the question that matters after Android silently revokes something on update.
library;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../state/permission_audit.dart';
import 'widgets/permission_audit_list.dart';

/// Live probe over `permission_handler`, mapping each registry id to a real status.
Future<PermissionGrant> livePermissionProbe(String id) async {
  Future<PermissionGrant> of(Permission p) async {
    final s = await p.status;
    if (s.isGranted || s.isLimited) return PermissionGrant.granted;
    if (s.isPermanentlyDenied) return PermissionGrant.permanentlyDenied;
    if (s.isDenied || s.isRestricted) return PermissionGrant.denied;
    return PermissionGrant.unknown;
  }

  return switch (id) {
    'notification' => of(Permission.notification),
    'bluetoothScan' => of(Permission.bluetoothScan),
    'locationWhenInUse' => of(Permission.locationWhenInUse),
    'ignoreBatteryOptimizations' => of(Permission.ignoreBatteryOptimizations),
    'exactAlarm' => of(Permission.scheduleExactAlarm),
    'camera' => of(Permission.camera),
    // Health Connect grants are not visible through permission_handler; reporting
    // "unknown" is honest, and unknown is deliberately not treated as a failure.
    _ => PermissionGrant.unknown,
  };
}

final _auditProvider = FutureProvider<List<AuditedPermission>>((ref) async {
  final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  return auditPermissions(sdkInt, livePermissionProbe);
});

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audit = ref.watch(_auditProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: audit.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not read permissions: $e')),
        data: (items) => RefreshIndicator(
          // Grants change outside the app, so re-reading on pull is the whole point.
          onRefresh: () async => ref.invalidate(_auditProvider),
          child: PermissionAuditList(
            audit: items,
            onFix: (p) async {
              await openAppSettings();
              ref.invalidate(_auditProvider);
            },
          ),
        ),
      ),
    );
  }
}
