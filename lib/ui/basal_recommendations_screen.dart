import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ml/basal_recommender.dart';
import '../state/providers.dart';

/// Suggested basal-profile changes from repeated time-of-day sensitivity trends.
/// Read-only and advisory — the app never changes pump settings.
class BasalRecommendationsScreen extends ConsumerWidget {
  const BasalRecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = ref.watch(basalRecommendationProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Basal suggestions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: cs.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'These suggestions come from your own carb-free (basal-dominant) '
                'glucose trends learned over the last few weeks. They are '
                'informational — make any changes on the pump yourself and discuss '
                'them with your care team. The app never adjusts your pump.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!rec.hasSuggestions)
            _EmptyState(trainedDays: rec.trainedDays)
          else ...[
            Text('Based on ${rec.trainedDays} days of history',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            for (final s in rec.segments) _SegmentCard(rec: s),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.trainedDays});
  final int trainedDays;

  @override
  Widget build(BuildContext context) {
    final enough = trainedDays >= 14;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(enough ? Icons.check_circle_outline : Icons.hourglass_empty,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            enough
                ? 'No confident changes to suggest — your basal looks well matched '
                    'to your fasting trends.'
                : 'Not enough consistent history yet. After about two weeks of data '
                    'the app can spot repeated basal trends.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({required this.rec});
  final BasalSegmentRecommendation rec;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final up = rec.isIncrease;
    final accent = up ? cs.error : cs.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(up ? Icons.trending_up : Icons.trending_down, color: accent),
                const SizedBox(width: 8),
                Text(
                  '${_hhmm(rec.startMinuteOfDay)}–${_hhmm(rec.endMinuteOfDay)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                _ConfidenceChip(confidence: rec.confidence),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Rate(label: 'Current', value: rec.currentRate),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward, color: accent),
                ),
                _Rate(label: 'Suggested', value: rec.suggestedRate, accent: accent),
                const Spacer(),
                Text(
                  '${up ? '+' : ''}${(rec.changeFraction * 100).round()}%',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: accent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(rec.rationale, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  static String _hhmm(int minute) {
    final h = (minute ~/ 60) % 24;
    final m = minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class _Rate extends StatelessWidget {
  const _Rate({required this.label, required this.value, this.accent});
  final String label;
  final double value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text('${value.toStringAsFixed(2)} U/hr',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: accent)),
      ],
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text('confidence $pct%'),
      labelStyle: Theme.of(context).textTheme.labelSmall,
    );
  }
}
