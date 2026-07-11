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
            'harmless on its own, but worth noticing if it stays red. A row in '
            'amber hasn\'t failed, but hasn\'t succeeded recently either — the '
            'most common way a background job actually breaks is by silently no '
            'longer being scheduled at all, which never shows up as a failure.',
          ),
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
    // TASK-266: never-attempted is its own neutral state -- a green check means
    // "verified healthy", which a subsystem that has never run has no basis to
    // claim (fresh install, or demo mode where syncHealth is disabled).
    final neverRun = health.lastAttemptAt == null;
    // TASK-265: stale (amber) is checked only when NOT already unhealthy (red) --
    // a real recorded failure is worse than "just old", so it takes priority.
    final stale = !unhealthy &&
        !neverRun &&
        health.isStale(DateTime.now(), subsystem.expectedCadence);
    return Card(
      color: unhealthy
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4)
          : stale
              ? Theme.of(
                  context,
                ).colorScheme.tertiaryContainer.withValues(alpha: 0.4)
              : null,
      child: ListTile(
        leading: Icon(
          neverRun
              ? Icons.help_outline
              : unhealthy
                  ? Icons.error_outline
                  : stale
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
          color: neverRun
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : unhealthy
                  ? Theme.of(context).colorScheme.error
                  : stale
                      ? Colors.amber.shade800
                      : Colors.green,
        ),
        title: Text(subsystem.label),
        subtitle: Text(_subtitle(health, stale)),
      ),
    );
  }

  String _subtitle(SubsystemHealth h, bool stale) {
    if (h.lastAttemptAt == null) return 'Never run yet';
    final last = h.lastSuccessAt == null
        ? 'Never succeeded'
        : 'Last success: ${_relative(h.lastSuccessAt!)}';
    if (h.consecutiveFailures == 0) {
      return stale ? '$last · no recent activity, worth checking' : last;
    }
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

  /// TASK-265: Garmin delivery is CGM-push-triggered at ~5 minutes (GarminSender.kt
  /// debounces to a 60s floor, but the real drive rate is every CGM reading) --
  /// generous 3x headroom above that before a run with no recorded failures still
  /// gets flagged. Only meaningful once a success has landed at least once THIS
  /// session (this health is session-only, never persisted), so a fresh launch
  /// correctly reads "no send attempted yet", not stale.
  static const _staleAfter = Duration(minutes: 15);

  @override
  Widget build(BuildContext context) {
    final lastSuccessMs = health?['lastSuccessAtMs'] as int?;
    final failures = (health?['consecutiveFailures'] as int?) ?? 0;
    final unhealthy = !loading && failures > 0;
    // TASK-266: no success recorded and no failures either covers BOTH "not
    // available" (health == null, e.g. no native bridge / demo mode) and "no send
    // attempted yet this session" -- neither is "verified healthy", so neither
    // should render the green check.
    final neverRun = !loading && !unhealthy && lastSuccessMs == null;
    final stale = !loading &&
        !unhealthy &&
        !neverRun &&
        lastSuccessMs != null &&
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(lastSuccessMs),
            ) >
            _staleAfter;
    final subtitle = loading
        ? 'Checking…'
        : health == null
            ? 'Not available (no native bridge, e.g. demo mode)'
            : lastSuccessMs == null
                ? (failures > 0
                    ? 'Never succeeded — failed $failures time(s) in a row'
                    : 'No send attempted yet this session')
                : 'Last success: ${_SubsystemTile._relative(DateTime.fromMillisecondsSinceEpoch(lastSuccessMs))}'
                    '${failures > 0 ? ' · failed $failures time(s) in a row since' : ''}'
                    '${stale ? ' · no recent activity, worth checking' : ''}';
    return Card(
      color: unhealthy
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4)
          : stale
              ? Theme.of(
                  context,
                ).colorScheme.tertiaryContainer.withValues(alpha: 0.4)
              : null,
      child: ListTile(
        leading: Icon(
          loading
              ? Icons.hourglass_empty
              : neverRun
                  ? Icons.help_outline
                  : unhealthy
                      ? Icons.error_outline
                      : stale
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
          color: neverRun
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : unhealthy
                  ? Theme.of(context).colorScheme.error
                  : stale
                      ? Colors.amber.shade800
                      : Colors.green,
        ),
        title: const Text('Garmin watch delivery'),
        subtitle: Text(
          '$subtitle\n(this session only — not persisted across restarts)',
        ),
        isThreeLine: true,
      ),
    );
  }
}
