import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/units.dart';
import '../feedback/annotations.dart';
import '../insights/reading_explainer.dart';
import '../state/providers.dart';

/// "Explain this reading": shows the engine's ranked causal hypotheses for a past
/// high/low, each acceptable as a one-tap [Annotation]. Pops with the accepted
/// annotation (or null) — the caller persists it.
class ExplainReadingScreen extends ConsumerWidget {
  const ExplainReadingScreen({
    super.key,
    required this.at,
    required this.mgdl,
    required this.explanations,
    this.iobUnits,
    this.cobGrams,
  });

  final DateTime at;
  final double mgdl;

  /// Pre-computed by the caller (which owns the data slices around [at]).
  final List<Explanation> explanations;

  final double? iobUnits;
  final double? cobGrams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(glucoseUnitProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Explain this reading')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    Mgdl(mgdl).display(unit),
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(unit.label),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(TimeOfDay.fromDateTime(at).format(context)),
                      if (iobUnits != null)
                        Text('IOB ${iobUnits!.toStringAsFixed(1)} U',
                            style: Theme.of(context).textTheme.bodySmall),
                      if (cobGrams != null)
                        Text('COB ${cobGrams!.toStringAsFixed(0)} g',
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Most likely explanations',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (explanations.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nothing in the surrounding data points to a clear '
                    'cause for this reading.'),
              ),
            ),
          for (final e in explanations)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(e.title,
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                        _ScoreChip(score: e.score),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(e.detail),
                    if (e.suggestedAnnotation != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: () => Navigator.of(context)
                              .pop<Annotation>(e.suggestedAnnotation),
                          child: const Text('This is what happened'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Accepting an explanation records it against this period so future '
            'model training accounts for it.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.outline),
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (score) {
      >= 0.7 => ('strong fit', Colors.green),
      >= 0.4 => ('plausible', Colors.orange),
      _ => ('possible', Colors.grey),
    };
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
  }
}
