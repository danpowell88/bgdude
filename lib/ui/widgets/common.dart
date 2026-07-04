/// Small shared presentation widgets used across screens.
library;

import 'package:flutter/material.dart';

import '../../analytics/bolus_advisor.dart';

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
