import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pump/pump_snapshot.dart';
import '../state/app_flags.dart';
import '../state/dev_flags.dart';
import '../state/providers.dart';
import 'protocol_explorer_screen.dart';
import 'widgets/dev_flags_panel.dart';

/// Developer menu — the home for low-level, non-consumer tools. Kept out of the main
/// Settings flow so day-to-day use isn't cluttered; everything here is diagnostic and
/// read-only. New debugging screens (raw message monitor, BLE/connection inspector,
/// on-device log ring buffer, history-log raw viewer) land here as they're built — see
/// ROADMAP §4-5.
class DeveloperScreen extends ConsumerStatefulWidget {
  const DeveloperScreen({super.key});

  @override
  ConsumerState<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends ConsumerState<DeveloperScreen> {
  DevFlagStore? _flags;
  Map<String, bool> _values = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadFlags());
  }

  Future<void> _loadFlags() async {
    final store = await DevFlagStore.load();
    if (!mounted) return;
    setState(() {
      _flags = store;
      _values = store.all;
    });
  }

  Future<void> _setFlag(DevFlag flag, bool value) async {
    final store = _flags;
    if (store == null) return;
    await store.set(flag, value);
    if (!mounted) return;
    setState(() => _values = store.all);
  }

  Future<void> _resetFlags() async {
    final store = _flags;
    if (store == null) return;
    await store.resetAll();
    if (!mounted) return;
    setState(() => _values = store.all);
  }

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(pumpConnectionProvider).valueOrNull;
    final connected = conn?.stage == PumpConnectionStage.connected;

    return Scaffold(
      appBar: AppBar(title: const Text('Developer')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Low-level diagnostics. Everything here is read-only — nothing can affect '
              'insulin delivery.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          // Issue #96: experiment flags read from one store, rendered in one place,
          // so trialling something never adds a switch to consumer Settings.
          const Divider(),
          DevFlagsPanel(
            values: _values,
            onChanged: _setFlag,
            onReset: _resetFlags,
          ),
          const Divider(),
          // Entering demo mode without redoing onboarding — a developer's shortcut.
          // The EXIT control stays in consumer Settings: demo mode is entered by
          // ordinary users on release builds where this menu does not exist, and
          // hiding the only way out behind it would strand them.
          ListTile(
            key: const Key('dev-enter-demo-mode'),
            leading: const Icon(Icons.science_outlined),
            title: const Text('Enter demo mode'),
            subtitle: const Text(
                'Switch to the simulated pump + CGM without redoing onboarding'),
            enabled: !ref.watch(devModeProvider),
            onTap: () async {
              ref.read(devModeProvider.notifier).state = true;
              await (await AppFlags.load()).setDevMode(true);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.travel_explore),
            title: const Text('Protocol Explorer'),
            subtitle: Text(connected
                ? 'Fire read-only pump reads & inspect raw + decoded responses'
                : 'Fire read-only pump reads (pair your pump first)'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const ProtocolExplorerScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
