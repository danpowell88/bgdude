import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/units.dart';
import '../integrations/nightscout.dart';
import '../state/app_flags.dart';
import '../state/ble_permissions.dart';
import '../state/providers.dart';
import 'app_routes.dart';

/// Nightscout upload configuration section.
class _NightscoutSection extends ConsumerStatefulWidget {
  const _NightscoutSection();
  @override
  ConsumerState<_NightscoutSection> createState() => _NightscoutSectionState();
}

class _NightscoutSectionState extends ConsumerState<_NightscoutSection> {
  late final TextEditingController _url;
  late final TextEditingController _secret;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(nightscoutConfigProvider);
    _url = TextEditingController(text: cfg.baseUrl);
    _secret = TextEditingController(text: cfg.apiSecret);
  }

  @override
  void dispose() {
    _url.dispose();
    _secret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(nightscoutConfigProvider);
    void save(NightscoutConfig next) =>
        ref.read(nightscoutConfigProvider.notifier).save(next);

    return ExpansionTile(
      leading: const Icon(Icons.cloud_upload_outlined),
      title: const Text('Nightscout'),
      subtitle: Text(cfg.enabled ? 'Uploading' : 'Off'),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Upload to Nightscout'),
          value: cfg.enabled,
          onChanged: (v) => save(cfg.copyWith(enabled: v)),
        ),
        TextField(
          controller: _url,
          decoration: const InputDecoration(
              labelText: 'Base URL', hintText: 'https://your-site.example'),
          onChanged: (v) => save(cfg.copyWith(baseUrl: v.trim())),
        ),
        TextField(
          controller: _secret,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'API secret'),
          onChanged: (v) => save(cfg.copyWith(apiSecret: v)),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await ref.read(nightscoutClientProvider).testConnection();
              messenger.showSnackBar(SnackBar(
                  content: Text(ok ? 'Connected ✓' : 'Could not connect')));
            },
            child: const Text('Test connection'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// App settings: units, advanced mode, and dev mode (the in-app t:slim + CGM
/// simulator so the whole app is usable without hardware).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(glucoseUnitProvider);
    final advanced = ref.watch(advancedModeProvider);
    final devMode = ref.watch(devModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Demo mode can only be *entered* during onboarding — there's no manual switch
          // in here. When it's on, show a read-only status row with a one-tap exit.
          if (devMode) ...[
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Demo mode'),
              subtitle: const Text(
                  'Running against a simulated t:slim X2 + Dexcom. Exit when you\'re '
                  'ready to pair your real pump.'),
              trailing: OutlinedButton.icon(
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Exit'),
                onPressed: () async {
                  ref.read(devModeProvider.notifier).state = false;
                  await (await AppFlags.load()).setDevMode(false);
                  try {
                    await ref.read(pumpClientProvider).startScan();
                  } catch (_) {}
                },
              ),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.water_drop_outlined),
            title: const Text('Glucose units'),
            trailing: SegmentedButton<GlucoseUnit>(
              segments: const [
                ButtonSegment(value: GlucoseUnit.mmol, label: Text('mmol/L')),
                ButtonSegment(value: GlucoseUnit.mgdl, label: Text('mg/dL')),
              ],
              selected: {unit},
              onSelectionChanged: (s) =>
                  ref.read(glucoseUnitProvider.notifier).set(s.first),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            subtitle: const Text('Sex, age & diabetes history — feeds the models'),
            onTap: () => AppRoutes.push(context, AppRoute.profile),
          ),
          ListTile(
            leading: const Icon(Icons.assessment_outlined),
            title: const Text('Reports'),
            subtitle: const Text(
                'AGP, time-in-range & episodes from confirmed data · PDF/CSV export'),
            onTap: () => AppRoutes.push(context, AppRoute.reports),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Confirm events'),
            subtitle: const Text(
                'Review detected meals, compression lows & more as real data'),
            trailing: ref.watch(pendingConfirmationsProvider).maybeWhen(
                  data: (items) => items.isEmpty
                      ? null
                      : Badge(label: Text('${items.length}')),
                  orElse: () => null,
                ),
            onTap: () => AppRoutes.push(context, AppRoute.confirmationInbox),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Notifications'),
            subtitle: const Text(
                'Opt in/out per alert, set intensity, sound & repeat alerts'),
            onTap: () => AppRoutes.push(context, AppRoute.notificationSettings),
          ),
          ListTile(
            leading: const Icon(Icons.directions_run),
            title: const Text('Exercise mode'),
            subtitle: const Text(
                'Announce a workout — leads low alerts and suggests a pre-snack'),
            onTap: () => AppRoutes.push(context, AppRoute.exerciseMode),
          ),
          ListTile(
            leading: const Icon(Icons.medication_outlined),
            title: const Text('Medication / steroid mode'),
            subtitle: const Text(
                'On a steroid course? Raise expected insulin needs while active'),
            onTap: () => AppRoutes.push(context, AppRoute.medicationMode),
          ),
          // Issue #376: first of the three, deliberately — if notifications are
          // off, nothing below it can reach the user anyway.
          const _NotificationsDisabledTile(),
          const _BatteryExemptionTile(), // TASK-183
          const _ExactAlarmExemptionTile(), // TASK-239
          ListTile(
            leading: const Icon(Icons.bloodtype_outlined),
            title: const Text('Pump'),
            subtitle: const Text(
                'Live status, insulin today, reservoir, alarms & events'),
            onTap: () => AppRoutes.push(context, AppRoute.pump),
          ),
          ListTile(
            leading: const Icon(Icons.bluetooth_searching),
            title: const Text('Glucose meter'),
            subtitle: const Text(
                'Import fingersticks from a Bluetooth meter (Accu-Chek Guide Me, etc.)'),
            onTap: () => AppRoutes.push(context, AppRoute.glucoseMeter),
          ),
          ListTile(
            leading: const Icon(Icons.medication_outlined),
            title: const Text('Therapy profile'),
            subtitle: const Text('Basal, ISF, carb ratio & targets from your pump'),
            onTap: () => AppRoutes.push(context, AppRoute.therapySettings),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.tune),
            title: const Text('Advanced mode'),
            subtitle: const Text(
                'Show prediction decomposition and model internals throughout'),
            value: advanced,
            onChanged: (v) =>
                ref.read(advancedModeProvider.notifier).state = v,
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Model internals'),
            subtitle: const Text(
                'Sensitivity, time-of-day profile, forecaster & error grid'),
            onTap: () => AppRoutes.push(context, AppRoute.advanced),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Basal suggestions'),
            subtitle: const Text(
                'Profile changes from repeated fasting trends (advisory)'),
            onTap: () => AppRoutes.push(context, AppRoute.basalRecommendations),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.thermostat_outlined),
            title: const Text('Weather'),
            subtitle: const Text(
                'Heat-aware low alerts + weather↔glucose (Open-Meteo, free)'),
            onTap: () => AppRoutes.push(context, AppRoute.weatherSettings),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.qr_code_scanner),
            title: const Text('Barcode food lookup'),
            subtitle: const Text(
                'Scan/search sends the code to Open Food Facts (public, free). '
                'Off = bundled offline Australian foods only.'),
            value: ref.watch(barcodeLookupEnabledProvider),
            onChanged: (v) =>
                ref.read(barcodeLookupEnabledProvider.notifier).set(v),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Nutrition-label AI'),
            subtitle: Text(ref.watch(panelModelProvider).installed
                ? 'On-device Gemma model installed'
                : 'Optional on-device model for tricky labels'),
            onTap: () => AppRoutes.push(context, AppRoute.aiModel),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Sync health data now'),
            subtitle: const Text(
                'Pull sleep, HRV, resting HR, steps & workouts from Health Connect'),
            enabled: !devMode,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(healthSyncServiceProvider).requestPermissions();
                final n = await ref.read(appJobsProvider).syncHealth();
                messenger.showSnackBar(
                    SnackBar(content: Text('Synced $n health samples.')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(
                    content: Text('Health sync failed: $e')));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.query_stats),
            title: const Text('Forecast accuracy'),
            subtitle: const Text('How the predictions score against outcomes'),
            onTap: () => AppRoutes.push(context, AppRoute.modelAccuracy),
          ),
          ListTile(
            leading: const Icon(Icons.model_training),
            title: const Text('Retrain forecaster now'),
            subtitle: const Text('Rebuild the learned correction from your history'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                  const SnackBar(content: Text('Training…')));
              final outcome = await ref.read(appJobsProvider).trainForecaster();
              messenger.showSnackBar(SnackBar(
                content: Text(!outcome.trained
                    ? 'Not enough data yet to train.'
                    : outcome.promoted
                        ? 'Promoted: RMSE ${outcome.candidateRmse?.toStringAsFixed(1)} '
                            'vs baseline ${outcome.baselineRmse?.toStringAsFixed(1)}.'
                        : 'Kept current model (${outcome.reasons.join('; ')}).'),
              ));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('Re-pair pump'),
            subtitle: const Text('Start a fresh scan / pairing'),
            enabled: !devMode,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              // TASK-226: a permission revoked since onboarding (or never granted on
              // this Android version) must re-prompt, not silently fail to scan.
              final ble = await requestBlePermissions();
              if (!ble.granted) {
                messenger.showSnackBar(bleDeniedSnackBar(ble));
                return;
              }
              await ref.read(pumpClientProvider).startScan();
            },
          ),
          ListTile(
            leading: const Icon(Icons.link_off),
            title: const Text('Unpair pump'),
            enabled: !devMode,
            onTap: () => ref.read(pumpClientProvider).unpair(),
          ),
          // Developer menu (Protocol Explorer + low-level diagnostics) is a debug-build
          // tool only — hidden from release builds along with its native logcat dump.
          if (kDebugMode) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.developer_mode),
              title: const Text('Developer'),
              subtitle: const Text(
                  'Protocol Explorer & low-level pump diagnostics (read-only)'),
              onTap: () => AppRoutes.push(context, AppRoute.developer),
            ),
          ],
          const Divider(),
          const _NightscoutSection(),
          const Divider(),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'bgdude',
            applicationVersion: '0.1.0',
            aboutBoxChildren: [
              Text('A personal t:slim X2 companion. Reads only — never delivers '
                  'insulin. Informational; not a substitute for your CGM/pump '
                  'alarms or clinical advice.'),
            ],
          ),
        ],
      ),
    );
  }
}


/// TASK-183: battery-optimization exemption. App Standby/Doze throttles BLE
/// callback delivery and defers the WorkManager summary backstop on an idle
/// phone; a continuous glucose monitor needs the exemption. Shows the current
/// state (no nagging) and only asks when tapped.
class _BatteryExemptionTile extends StatefulWidget {
  const _BatteryExemptionTile();

  @override
  State<_BatteryExemptionTile> createState() => _BatteryExemptionTileState();
}

class _BatteryExemptionTileState extends State<_BatteryExemptionTile> {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    Permission.ignoreBatteryOptimizations.isGranted.then((g) {
      if (mounted) setState(() => _granted = g);
    });
  }

  @override
  Widget build(BuildContext context) {
    final granted = _granted;
    return ListTile(
      leading: Icon(
        granted == true
            ? Icons.battery_charging_full
            : Icons.battery_alert_outlined,
        color: granted == false ? Theme.of(context).colorScheme.error : null,
      ),
      title: const Text('Keep running in background'),
      subtitle: Text(granted == true
          ? 'Battery optimisation exemption granted — monitoring won\'t be throttled.'
          : 'Android\'s battery saver can delay readings and alerts while the phone '
              'sleeps. Tap to allow bgdude to keep monitoring.'),
      onTap: granted == true
          ? null
          : () async {
              final status =
                  await Permission.ignoreBatteryOptimizations.request();
              if (mounted) setState(() => _granted = status.isGranted);
            },
    );
  }
}

/// Issue #376: surfaces a denied/revoked `POST_NOTIFICATIONS` grant.
///
/// The audit on that issue found this was the highest-consequence gap in the
/// permission flow: `init()` requests the permission once at first run and nothing
/// ever read the result, so a refusal — or a later revocation in system settings —
/// left every alert silently undeliverable with no indication anywhere. Battery
/// optimisation, which matters less, was already re-checked and re-offered here.
///
/// Follows [_ExactAlarmExemptionTile]'s shape: shown ONLY in the bad state, so it is
/// a warning rather than a permanent "all good" row. It is worded more urgently than
/// its siblings because the failure it describes is total — no alarms at all,
/// including urgent lows — rather than degraded timing.
class _NotificationsDisabledTile extends ConsumerStatefulWidget {
  const _NotificationsDisabledTile();

  @override
  ConsumerState<_NotificationsDisabledTile> createState() =>
      _NotificationsDisabledTileState();
}

class _NotificationsDisabledTileState
    extends ConsumerState<_NotificationsDisabledTile> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final enabled =
        await ref.read(notificationServiceProvider).areNotificationsEnabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    // Null (still checking) and true both render nothing — a warning that flashes
    // up during the async check and then vanishes would be worse than none.
    if (_enabled != false) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(Icons.notifications_off,
          color: Theme.of(context).colorScheme.error),
      title: const Text('Alerts are turned off'),
      subtitle: const Text(
          'Android is blocking bgdude\'s notifications, so NO alerts can reach '
          'you — including urgent lows. Tap to turn them back on.'),
      onTap: () async {
        // After a permanent denial this returns without showing any dialog, so the
        // re-check below is what keeps the warning visible instead of implying the
        // tap fixed it.
        await ref
            .read(notificationServiceProvider)
            .requestNotificationsPermission();
        await _refresh();
      },
    );
  }
}

/// TASK-239: exact-alarm permission. TASK-182's pre-bolus timer falls back to
/// an inexact alarm when this is denied (Android 13 makes it user-revocable;
/// Android 14+ denies it by default for new installs), which can fire 30-40
/// minutes late in Doze -- late enough that a pre-bolus timer meant to fire
/// before a meal fires after it instead, making the timer useless. Mirrors
/// [_BatteryExemptionTile]'s pattern: shows the current state (no nagging),
/// only prompts when tapped, and hides itself entirely once granted so it
/// never asks again after being addressed.
class _ExactAlarmExemptionTile extends ConsumerStatefulWidget {
  const _ExactAlarmExemptionTile();

  @override
  ConsumerState<_ExactAlarmExemptionTile> createState() =>
      _ExactAlarmExemptionTileState();
}

class _ExactAlarmExemptionTileState
    extends ConsumerState<_ExactAlarmExemptionTile> {
  bool? _canExact;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final canExact =
        await ref.read(notificationServiceProvider).canScheduleExactAlarms();
    if (mounted) setState(() => _canExact = canExact);
  }

  @override
  Widget build(BuildContext context) {
    final canExact = _canExact;
    // AC#2: this tile only ever appears in the denied state -- once granted
    // (or on a platform/OS version where it's simply not applicable and the
    // plugin reports true), it disappears entirely rather than sitting there
    // as a permanent "all good" row nobody needs to see again.
    if (canExact != false) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(Icons.alarm_off,
          color: Theme.of(context).colorScheme.error),
      title: const Text('Allow exact alarms'),
      subtitle: const Text(
          'Without this, the pre-bolus timer can fire 30-40 minutes late '
          'while the phone is idle. Tap to grant it in system settings.'),
      onTap: () async {
        await ref.read(notificationServiceProvider).requestExactAlarmPermission();
        // The OS doesn't callback on grant/deny from its settings screen --
        // re-check after the user returns to this screen.
        await _refresh();
      },
    );
  }
}
