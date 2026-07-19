/// The single, auditable inventory of every runtime permission bgdude needs (issue #376).
///
/// Declaring a permission in the manifest is not granting it, and the failures that
/// matter here are all silent: notifications denied means no glucose alarms; a missing
/// battery exemption means Doze kills the pump connection overnight; on Android 11 and
/// below a BLE scan without location permission returns zero results and looks exactly
/// like "no pump nearby". This file exists so that set is written down in one place,
/// with what breaks when each is missing, rather than being implied by scattered
/// `.request()` calls in onboarding and settings.
///
/// The registry and its filtering are pure so they can be tested without a device; the
/// live status lookups are injected via [PermissionProbe].
library;

/// How badly bgdude is degraded when a permission is missing.
enum PermissionSeverity {
  /// A core safety surface stops working — the user must know.
  critical,

  /// A feature is degraded but glucose monitoring and alarms still work.
  optional,
}

/// One runtime permission, with the user-facing reason and consequence.
class AppPermission {
  const AppPermission({
    required this.id,
    required this.title,
    required this.why,
    required this.whatBreaks,
    required this.severity,
    required this.requestedAt,
    this.minSdk,
    this.maxSdk,
  });

  final String id;
  final String title;

  /// The rationale shown before/alongside the OS prompt.
  final String why;

  /// The consequence of not granting it — the half users actually need.
  final String whatBreaks;
  final PermissionSeverity severity;

  /// Where in the app's lifecycle this is requested, so "requested too late" is
  /// reviewable rather than folklore.
  final String requestedAt;

  /// SDK bounds, inclusive, when the permission only exists on some versions.
  final int? minSdk;
  final int? maxSdk;

  bool appliesOn(int sdkInt) =>
      (minSdk == null || sdkInt >= minSdk!) &&
      (maxSdk == null || sdkInt <= maxSdk!);
}

/// Every runtime permission the app requests, in the order it should be asked for.
///
/// ACCESS_BACKGROUND_LOCATION is deliberately absent — see `doc/decisions/decision-17.md`.
const List<AppPermission> allAppPermissions = [
  AppPermission(
    id: 'notification',
    title: 'Notifications',
    why: 'Glucose alarms, pump alerts and reminders are delivered as notifications.',
    whatBreaks: 'No low or high alarms at all — the app looks fine and stays silent.',
    severity: PermissionSeverity.critical,
    requestedAt: 'Onboarding, before the first alarm can fire',
    minSdk: 33,
  ),
  AppPermission(
    id: 'bluetoothScan',
    title: 'Nearby devices (Bluetooth)',
    why: 'Used to find and connect to your pump over Bluetooth.',
    whatBreaks: 'The pump can never be found or reconnected.',
    severity: PermissionSeverity.critical,
    requestedAt: 'Onboarding "Get connected", and again from Re-pair pump',
    minSdk: 31,
  ),
  AppPermission(
    id: 'locationWhenInUse',
    title: 'Location',
    why: 'On Android 11 and below, scanning for any Bluetooth device legally '
        'requires location permission. bgdude never uses your position.',
    whatBreaks: 'Pump discovery silently finds nothing — indistinguishable from '
        'the pump being out of range.',
    severity: PermissionSeverity.critical,
    requestedAt: 'Onboarding "Get connected", and again from Re-pair pump',
    maxSdk: 30,
  ),
  AppPermission(
    id: 'ignoreBatteryOptimizations',
    title: 'Unrestricted battery use',
    why: 'Lets bgdude keep the pump connection alive while your phone is idle.',
    whatBreaks: 'Android suspends the app during Doze, so overnight readings and '
        'alarms stop until you next open it.',
    severity: PermissionSeverity.critical,
    requestedAt: 'Onboarding, and re-offered from Settings if later revoked',
  ),
  AppPermission(
    id: 'exactAlarm',
    title: 'Alarms & reminders',
    why: 'Pre-bolus and timed reminders need to fire at an exact time.',
    whatBreaks: 'Timed reminders drift or arrive late — some phones revoke this '
        'silently after an update.',
    severity: PermissionSeverity.optional,
    requestedAt: 'Settings, when a timed reminder is first enabled',
  ),
  AppPermission(
    id: 'healthConnect',
    title: 'Health Connect',
    why: 'Reads sleep, heart rate and activity to explain changes in your '
        'insulin sensitivity.',
    whatBreaks: 'Sensitivity insights lose their sleep and activity drivers; '
        'glucose monitoring is unaffected.',
    severity: PermissionSeverity.optional,
    requestedAt: 'Onboarding (skippable) and Settings',
  ),
  AppPermission(
    id: 'camera',
    title: 'Camera',
    why: 'Scans barcodes and reads meter panels.',
    whatBreaks: 'Barcode and panel scanning are unavailable; everything can '
        'still be entered by hand.',
    severity: PermissionSeverity.optional,
    requestedAt: 'On first use of a scanning screen',
  ),
];

/// The permissions that actually apply on this Android version, in ask-order.
List<AppPermission> permissionsForSdk(int sdkInt) =>
    [for (final p in allAppPermissions) if (p.appliesOn(sdkInt)) p];

/// Live status of one permission.
enum PermissionGrant { granted, denied, permanentlyDenied, unknown }

/// Resolves the live status of a permission id. Injected so the audit can be tested
/// without a device.
typedef PermissionProbe = Future<PermissionGrant> Function(String id);

/// A permission paired with its current state.
typedef AuditedPermission = ({AppPermission permission, PermissionGrant grant});

/// The full audit for this device: every applicable permission with its live status.
Future<List<AuditedPermission>> auditPermissions(
  int sdkInt,
  PermissionProbe probe,
) async {
  final out = <AuditedPermission>[];
  for (final p in permissionsForSdk(sdkInt)) {
    out.add((permission: p, grant: await probe(p.id)));
  }
  return out;
}

/// The critical permissions that are not granted — what a warning banner should say.
///
/// Treats [PermissionGrant.unknown] as NOT a problem: an unreadable status is not
/// evidence of denial, and crying wolf on it would train the user to ignore the banner.
List<AuditedPermission> criticalGaps(List<AuditedPermission> audit) => [
      for (final a in audit)
        if (a.permission.severity == PermissionSeverity.critical &&
            (a.grant == PermissionGrant.denied ||
                a.grant == PermissionGrant.permanentlyDenied))
          a,
    ];

/// Whether anything needs the user's attention at all.
bool hasCriticalGap(List<AuditedPermission> audit) => criticalGaps(audit).isNotEmpty;
