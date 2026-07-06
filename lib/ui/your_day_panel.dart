import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/units.dart';
import '../state/providers.dart';
import 'widgets/common.dart';

/// The "Your Day" panel: at-a-glance current stats plus a plain-language narrative and
/// actionable suggestions/trends for the day. Sits at the top of the Today tab.
class YourDayPanel extends ConsumerWidget {
  const YourDayPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final narrative = ref.watch(dailyNarrativeProvider);
    final metrics = ref.watch(todayMetricsProvider);
    final snap = ref.watch(pumpSnapshotProvider).valueOrNull;
    final unit = ref.watch(glucoseUnitProvider);
    final cs = Theme.of(context).colorScheme;

    final bg = snap?.cgmMgdl;
    return Card(
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your day', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(narrative.headline,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(narrative.body),
            const SizedBox(height: 12),
            Row(
              children: [
                StatTile(
                    label: 'Glucose',
                    value: bg == null ? '—' : Mgdl(bg.toDouble()).display(unit)),
                StatTile(
                    label: 'IOB',
                    value: snap?.iobUnits?.toStringAsFixed(1) ?? '—',
                    suffix: 'U'),
                StatTile(
                    label: 'TIR today',
                    value: metrics.readingCount == 0
                        ? '—'
                        : '${(metrics.timeInRange * 100).round()}',
                    suffix: '%'),
              ],
            ),
            if (narrative.suggestions.isNotEmpty) ...[
              const Divider(height: 24),
              for (final s in narrative.suggestions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right, size: 20),
                      Expanded(child: Text(s)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

