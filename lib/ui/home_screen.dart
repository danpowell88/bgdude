import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/samples.dart';
import '../core/units.dart';
import '../pump/pump_snapshot.dart';
import '../state/providers.dart';
import 'advanced_screen.dart';
import 'bolus_advisor_screen.dart';
import 'widgets/glucose_hero.dart';
import 'widgets/prediction_chart.dart';

/// Simple-mode home: the everyday glanceable view. Advanced internals live one tap away.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(glucoseUnitProvider);
    final connection = ref.watch(pumpConnectionProvider);
    final snapshot = ref.watch(pumpSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('bgdude'),
        actions: [
          IconButton(
            icon: Icon(unit == GlucoseUnit.mmol ? Icons.water_drop : Icons.science),
            tooltip: 'Toggle units',
            onPressed: () => ref.read(glucoseUnitProvider.notifier).state =
                unit == GlucoseUnit.mmol ? GlucoseUnit.mgdl : GlucoseUnit.mmol,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Advanced',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdvancedScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(pumpClientProvider).requestStatus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ConnectionBanner(connection: connection),
            const SizedBox(height: 12),
            snapshot.when(
              data: (s) => _Dashboard(snapshot: s, unit: unit),
              loading: () => const _WaitingCard(),
              error: (e, _) => _ErrorCard(message: '$e'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BolusAdvisorScreen()),
        ),
        icon: const Icon(Icons.calculate),
        label: const Text('Bolus advisor'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlucoseHero(
          mgdl: snapshot.cgmMgdl?.toDouble(),
          trend: snapshot.cgmTrend ?? GlucoseTrend.unknown,
          unit: unit,
          time: snapshot.cgmTime,
        ),
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
        Text('Next few hours',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const SizedBox(height: 200, child: PredictionChart()),
        const SizedBox(height: 8),
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

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.connection});
  final AsyncValue<PumpConnection> connection;

  @override
  Widget build(BuildContext context) {
    final c = connection.valueOrNull ?? PumpConnection.idle;
    final (color, label) = switch (c.stage) {
      PumpConnectionStage.connected => (Colors.green, 'Connected${c.pumpName != null ? ' · ${c.pumpName}' : ''}'),
      PumpConnectionStage.scanning => (Colors.orange, 'Searching for pump…'),
      PumpConnectionStage.awaitingPairingCode => (Colors.orange, 'Enter pairing code from pump'),
      PumpConnectionStage.disconnected => (Colors.red, 'Disconnected — reconnecting'),
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
