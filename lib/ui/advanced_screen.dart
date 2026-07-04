import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Advanced mode: surfaces the model internals the simple UI hides — sensitivity
/// context, prediction decomposition toggle, and (once wired to storage) the model
/// registry / error-grid stats. Everything here is opt-in.
class AdvancedScreen extends ConsumerWidget {
  const AdvancedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advanced = ref.watch(advancedModeProvider);
    final ctx = ref.watch(sensitivityContextProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Advanced mode'),
            subtitle: const Text(
                'Show prediction decomposition and model internals throughout the app'),
            value: advanced,
            onChanged: (v) =>
                ref.read(advancedModeProvider.notifier).state = v,
          ),
          const Divider(),
          Text('Today\'s insulin-sensitivity context',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(context, 'Resistance multiplier',
                      '×${ctx.effectiveMultiplier.toStringAsFixed(2)}'),
                  _kv(context, 'Raw multiplier',
                      '×${ctx.resistanceMultiplier.toStringAsFixed(2)}'),
                  _kv(context, 'Confidence',
                      '${(ctx.confidence * 100).round()}%'),
                  _kv(context, 'Drivers',
                      ctx.reasons.isEmpty ? 'none detected' : ctx.reasons.join(', ')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Model status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.psychology),
              title: Text('BG forecaster'),
              subtitle: Text(
                  'Deterministic baseline active. Learned residual trains overnight once '
                  '~2 weeks of data accrue and passes the error-grid gate before going live.'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.tune),
              title: Text('Sensitivity model'),
              subtitle: Text(
                  'Ridge regression over sleep / HRV / exercise / cycle context. Neutral '
                  'until ≥21 days of data.'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'These features are informational. The app reads from your pump only and never '
            'delivers insulin.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 170, child: Text(k)),
            Expanded(
                child: Text(v,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
