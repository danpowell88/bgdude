import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/rescue_carbs.dart';
import '../core/samples.dart';
import '../core/units.dart';
import '../insights/reading_explainer.dart';
import '../pump/pump_snapshot.dart';
import '../state/providers.dart';
import 'explain_reading_screen.dart';
import 'timeline_screen.dart';
import 'widgets/glucose_hero.dart';
import 'widgets/prediction_chart.dart';
import 'your_day_panel.dart';

export 'timeline_screen.dart' show TimelineEventCard;

/// The "Today" tab: the glanceable dashboard (current glucose, IOB, TIR, short-term
/// prediction) followed by today's interactive event stream. One page, so the day's
/// state and the events that shaped it live together.
class TodayTab extends ConsumerWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(glucoseUnitProvider);
    final connection = ref.watch(pumpConnectionProvider);
    final snapshot = ref.watch(pumpSnapshotProvider);

    // Newest events first, rendered inline in the same scroll view (no nested
    // scrollable, so everything is in the tree and flows naturally).
    final events = ref.watch(dayEventsProvider);
    final ordered = [...events]..sort((a, b) => b.time.compareTo(a.time));

    return RefreshIndicator(
      onRefresh: () => ref.read(pumpClientProvider).requestStatus(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConnectionBanner(connection: connection),
          const SizedBox(height: 12),
          const _ColdStartCard(),
          const YourDayPanel(),
          const SizedBox(height: 12),
          snapshot.when(
            data: (s) => _Dashboard(snapshot: s, unit: unit),
            loading: () => const _WaitingCard(),
            error: (e, _) => _ErrorCard(message: '$e'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Today', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('tap an event to explain or tag',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline)),
            ],
          ),
          const SizedBox(height: 4),
          if (ordered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No events yet today. Meals, boluses and glucose swings will appear '
                'here to review.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (final e in ordered) TimelineEventCard(event: e),
        ],
      ),
    );
  }
}

/// First-days guidance: shown in real mode while there's little history, so the app
/// explains what to set up and that the models sharpen over ~2 weeks.
class _ColdStartCard extends ConsumerWidget {
  const _ColdStartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devMode = ref.watch(devModeProvider);
    final day = ref.watch(dayDataProvider);
    // Only for real mode with thin history (< ~4h of readings).
    if (devMode || day.cgm.length >= 48) return const SizedBox.shrink();

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch_outlined),
                const SizedBox(width: 8),
                Text('Getting started',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            const Text('• Pair your pump in Settings, then enter the code it shows.'),
            const Text('• Add your therapy profile (basal/ISF/CR/targets).'),
            const Text('• Sync Health Connect for sleep/HRV context.'),
            const Text('• Log meals so the app learns how they treat you.'),
            const SizedBox(height: 6),
            Text(
              'Metrics need ~14 days and the models train once enough of your own '
              'data has accrued — until then predictions use the physiological '
              'baseline and a transparent heuristic.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 8),
            Text('Tip: turn on Dev mode in Settings to explore the full app with '
                'simulated data.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.snapshot, required this.unit});
  final PumpSnapshot snapshot;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rescue = ref.watch(rescueCarbAdviceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlucoseHero(
          mgdl: snapshot.cgmMgdl?.toDouble(),
          trend: snapshot.cgmTrend ?? GlucoseTrend.unknown,
          unit: unit,
          time: snapshot.cgmTime,
        ),
        if (rescue != null) ...[
          const SizedBox(height: 12),
          _RescueCard(advice: rescue),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _StatTile(
                    label: 'IOB',
                    value: snapshot.iobUnits?.toStringAsFixed(2) ?? '—',
                    suffix: 'U')),
            const SizedBox(width: 12),
            Expanded(
                child: _StatTile(
                    label: 'Basal',
                    value: snapshot.basalUnitsPerHour?.toStringAsFixed(2) ?? '—',
                    suffix: 'U/h')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _StatTile(
                    label: 'Reservoir',
                    value: snapshot.reservoirUnits?.toStringAsFixed(0) ?? '—',
                    suffix: 'U')),
            const SizedBox(width: 12),
            Expanded(
                child: _StatTile(
                    label: 'Battery',
                    value: snapshot.batteryPercent?.toString() ?? '—',
                    suffix: '%')),
          ],
        ),
        const SizedBox(height: 16),
        Text('Next few hours', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const SizedBox(height: 200, child: PredictionChart()),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _explainCurrent(context, ref),
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text('Explain this reading'),
          ),
        ),
        Text(
          'Predictions are informational and can be wrong. They do not replace your '
          'CGM or pump alarms.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    );
  }

  Future<void> _explainCurrent(BuildContext context, WidgetRef ref) async {
    final day = ref.read(dayDataProvider);
    final latest = day.latest;
    if (latest == null) return;
    final explanations = ReadingExplainer().explain(
      at: latest.time,
      cgm: day.cgm,
      boluses: day.boluses,
      basal: day.basal,
      carbs: day.carbs,
      settings: day.settings,
      wasAsleep: latest.time.hour >= 23 || latest.time.hour < 7,
    );
    if (!context.mounted) return;
    final annotation = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute<dynamic>(
        builder: (_) => ExplainReadingScreen(
          at: latest.time,
          mgdl: latest.mgdl,
          explanations: explanations,
        ),
      ),
    );
    if (annotation != null) {
      await ref.read(historyRepositoryProvider).saveAnnotation(annotation);
    }
  }
}

class _RescueCard extends StatelessWidget {
  const _RescueCard({required this.advice});
  final RescueCarbAdvice advice;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: advice.urgent ? cs.errorContainer : cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(advice.urgent ? Icons.emergency : Icons.cookie_outlined),
                const SizedBox(width: 8),
                Text('Rescue carbs: ${advice.grams.toStringAsFixed(0)} g',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(advice.reason),
            const SizedBox(height: 6),
            Text(advice.working.join('  ·  '),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.suffix});
  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(width: 4),
                Text(suffix, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBanner extends ConsumerWidget {
  const _ConnectionBanner({required this.connection});
  final AsyncValue<PumpConnection> connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = connection.valueOrNull ?? PumpConnection.idle;
    final (color, label) = switch (c.stage) {
      PumpConnectionStage.connected => (
          Colors.green,
          'Connected${c.pumpName != null ? ' · ${c.pumpName}' : ''}'
        ),
      PumpConnectionStage.scanning => (Colors.orange, 'Searching for pump…'),
      PumpConnectionStage.awaitingPairingCode => (
          Colors.orange,
          'Enter pairing code from pump'
        ),
      PumpConnectionStage.disconnected => (
          Colors.red,
          'Disconnected — reconnecting'
        ),
      PumpConnectionStage.error => (Colors.red, c.error ?? 'Error'),
      _ => (Colors.grey, c.stage.name),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          if (c.stage == PumpConnectionStage.disconnected ||
              c.stage == PumpConnectionStage.error ||
              c.stage == PumpConnectionStage.idle)
            TextButton(
              onPressed: () => ref.read(pumpClientProvider).startScan(),
              child: const Text('Reconnect'),
            ),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard();
  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Waiting for the first pump reading…')),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
      );
}
