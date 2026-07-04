import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/units.dart';
import '../integrations/nightscout.dart';
import '../state/providers.dart';
import 'advanced_screen.dart';
import 'model_accuracy_screen.dart';
import 'therapy_settings_screen.dart';

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
          SwitchListTile(
            secondary: const Icon(Icons.science_outlined),
            title: const Text('Dev mode (simulated pump)'),
            subtitle: const Text(
                'Run against a simulated t:slim X2 + Dexcom so you can see the full '
                'app — timeline, predictions, insights — without hardware.'),
            value: devMode,
            onChanged: (v) async {
              ref.read(devModeProvider.notifier).state = v;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('dev_mode', v);
            },
          ),
          const Divider(),
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
                  ref.read(glucoseUnitProvider.notifier).state = s.first,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.medication_outlined),
            title: const Text('Therapy profile'),
            subtitle: const Text('Basal, ISF, carb ratio & targets from your pump'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const TherapySettingsScreen()),
            ),
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdvancedScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Sync health data now'),
            subtitle: const Text(
                'Pull sleep, HRV, resting HR, steps & workouts from Health Connect'),
            enabled: !devMode,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await ref.read(healthSyncServiceProvider).requestPermissions();
              final n = await ref.read(appJobsProvider).syncHealth();
              messenger.showSnackBar(
                  SnackBar(content: Text('Synced $n health samples.')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.query_stats),
            title: const Text('Forecast accuracy'),
            subtitle: const Text('How the predictions score against outcomes'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const ModelAccuracyScreen()),
            ),
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
            onTap: () => ref.read(pumpClientProvider).startScan(),
          ),
          ListTile(
            leading: const Icon(Icons.link_off),
            title: const Text('Unpair pump'),
            enabled: !devMode,
            onTap: () => ref.read(pumpClientProvider).unpair(),
          ),
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
