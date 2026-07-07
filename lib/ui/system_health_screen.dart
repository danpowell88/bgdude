import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../insights/system_health.dart';
import '../state/providers.dart';

/// System health (TASK-201): last-success time + consecutive-failure count per
/// background subsystem, read-only. Reached from Advanced → "System health".
/// Recurring background failures otherwise only ever land in the diagnostics log
/// — this is the at-a-glance surface for noticing one before it quietly degrades
/// forecasts (a stale health sampler, an untrained model, missing weather context).
class SystemHealthScreen extends ConsumerWidget {
  const SystemHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(systemHealthProvider);
    final garmin = ref.watch(garminHealthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('System health')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
              'Background subsystems and when each last succeeded. A row in red '
              'has failed at least once since its last success — usually still '
              'harmless on its own, but worth noticing if it stays red.'),
          const SizedBox(height: 16),
          for (final s in Subsystem.values) _SubsystemTile(s, report.of(s)),
          const Divider(),
          garmin.when(
            loading: () => const _GarminTile(health: null, loading: true),
            error: (_, __) => const _GarminTile(health: null, loading: false),
            data: (h) => _GarminTile(health: h, loading: false),
          ),
        ],
      ),
    );
  }
}

class _SubsystemTile extends StatelessWidget {
  const _SubsystemTile(this.subsystem, this.health);
  final Subsystem subsystem;
  final SubsystemHealth health;

  @override
  Widget build(BuildContext context) {
    final unhealthy = health.isUnhealthy;
    return Card(
      color: unhealthy
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4)
          : null,
      child: ListTile(
        leading: Icon(
          unhealthy ? Icons.error_outline : Icons.check_circle_outline,
          color: unhealthy
              ? Theme.of(context).colorScheme.error
              : Colors.green,
        ),
        title: Text(subsystem.label),
        subtitle: Text(_subtitle(health)),
      ),
    );
  }

  String _subtitle(SubsystemHealth h) {
    if (h.lastAttemptAt == null) return 'Never run yet';
    final last = h.lastSuccessAt == null
        ? 'Never succeeded'
        : 'Last success: ${_relative(h.lastSuccessAt!)}';
    if (h.consecutiveFailures == 0) return last;
    final times = h.consecutiveFailures == 1 ? 'time' : 'times';
    return '$last · failed ${h.consecutiveFailures} $times in a row'
        '${h.lastError != null ? ' (${h.lastError})' : ''}';
  }

  static String _relative(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _GarminTile extends StatelessWidget {
  const _GarminTile({required this.health, required this.loading});
  final Map<String, dynamic>? health;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final lastSuccessMs = health?['lastSuccessAtMs'] as int?;
    final failures = (health?['consecutiveFailures'] as int?) ?? 0;
    final unhealthy = !loading && failures > 0;
    final subtitle = loading
        ? 'Checking…'
        : health == null
            ? 'Not available (no native bridge, e.g. demo mode)'
            : lastSuccessMs == null
                ? (failures > 0
                    ? 'Never succeeded — failed $failures time(s) in a row'
                    : 'No send attempted yet this session')
                : 'Last success: ${_SubsystemTile._relative(DateTime.fromMillisecondsSinceEpoch(lastSuccessMs))}'
                    '${failures > 0 ? ' · failed $failures time(s) in a row since' : ''}';
    return Card(
      color: unhealthy
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4)
          : null,
      child: ListTile(
        leading: Icon(
          loading
              ? Icons.hourglass_empty
              : unhealthy
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
          color: unhealthy ? Theme.of(context).colorScheme.error : Colors.green,
        ),
        title: const Text('Garmin watch delivery'),
        subtitle: Text('$subtitle\n(this session only — not persisted across restarts)'),
        isThreeLine: true,
      ),
    );
  }
}
