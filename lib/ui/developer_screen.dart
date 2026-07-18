import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pump/pump_snapshot.dart';
import '../state/providers.dart';
import 'message_monitor_screen.dart';
import 'protocol_explorer_screen.dart';

/// Developer menu — the home for low-level, non-consumer tools. Kept out of the main
/// Settings flow so day-to-day use isn't cluttered; everything here is diagnostic and
/// read-only. New debugging screens (raw message monitor, BLE/connection inspector,
/// on-device log ring buffer, history-log raw viewer) land here as they're built — see
/// ROADMAP §4-5.
class DeveloperScreen extends ConsumerWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          // Issue #92: what the pump sends unprompted, as opposed to the Explorer's
          // ask-and-see flow.
          ListTile(
            leading: const Icon(Icons.stream),
            title: const Text('Message monitor'),
            subtitle: const Text(
                'Live tail of everything the pump sends, with a bounded history'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const MessageMonitorScreen()),
            ),
          ),
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
