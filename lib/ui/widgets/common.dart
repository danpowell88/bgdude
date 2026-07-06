/// Small shared presentation widgets used across screens.
library;

import 'package:flutter/material.dart';

import '../../analytics/bolus_advisor.dart';

/// The visual variant of a [StatTile] (TASK-107), one per original private widget:
/// - [card] — Home's boxed stat (a [Card], label-first, headline value + suffix). The
///   caller wraps it in an [Expanded]; the tile does not self-expand.
/// - [panel] — Your-day's stat (self-[Expanded], label-first, titleLarge value + suffix).
/// - [metric] — the reports' metric (self-[Expanded], centred, value-above-label; no suffix).
enum StatVariant { card, panel, metric }

/// A single labelled statistic. Consolidates the four near-identical private tiles that
/// used to live in home_screen, your_day_panel, insulin_report_screen and
/// glucose_report_screen (TASK-107). Pick the look with [variant].
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.suffix = '',
    this.variant = StatVariant.panel,
  });

  final String label;
  final String value;
  final String suffix;
  final StatVariant variant;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    if (variant == StatVariant.metric) {
      return Expanded(
        child: Column(
          children: [
            Text(value, style: t.titleLarge),
            Text(label, style: t.labelSmall),
          ],
        ),
      );
    }

    final isCard = variant == StatVariant.card;
    final valueStyle = isCard ? t.headlineSmall : t.titleLarge;
    final labelStyle = isCard ? t.labelMedium : t.labelSmall;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        if (isCard) const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: valueStyle),
            if (suffix.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(suffix, style: t.bodySmall),
            ],
          ],
        ),
      ],
    );

    if (isCard) {
      return Card(
        child: Padding(padding: const EdgeInsets.all(16), child: column),
      );
    }
    return Expanded(child: column);
  }
}

/// A labelled key-value row ("Carbs   60 g") used in stat/working cards.
class KvRow extends StatelessWidget {
  const KvRow(this.label, this.value, {super.key, this.labelWidth = 130});

  final String label;
  final String value;
  final double labelWidth;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

/// Renders an advisor's step-by-step working ([AdviceStep] list).
class AdviceWorkingList extends StatelessWidget {
  const AdviceWorkingList(this.steps, {super.key});

  final List<AdviceStep> steps;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(step.label,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  Expanded(child: Text(step.value)),
                ],
              ),
            ),
        ],
      );
}

/// Renders advisory caveat notes with an info icon.
class AdviceNotesList extends StatelessWidget {
  const AdviceNotesList(this.notes, {super.key});

  final List<String> notes;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(note,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
            ),
        ],
      );
}
