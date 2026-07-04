import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/units.dart';
import '../state/providers.dart';

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
          SwitchListTile(
            secondary: const Icon(Icons.tune),
            title: const Text('Advanced mode'),
            subtitle: const Text(
                'Show prediction decomposition and model internals throughout'),
            value: advanced,
            onChanged: (v) =>
                ref.read(advancedModeProvider.notifier).state = v,
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
