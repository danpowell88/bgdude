/// This week's alert load, for the Insights surface (issue #171).
///
/// Its own widget rather than a private one inside InsightsScreen so it can be tested
/// with a single provider override — the full screen pulls in the repository, health
/// features and sensitivity model, none of which this card reads.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../insights/alarm_fatigue.dart';
import '../../insights/notification_prefs.dart';
import '../../state/providers.dart';

/// This week's alert load (issue #171).
///
/// Alarm fatigue is the top reason people abandon alerting, so the point of this card
/// is to make the trend visible BEFORE someone gives up on alerts — a count they can
/// act on, not a number to admire.
///
/// Renders nothing at all in a quiet week: a card reading "0 alerts" every day is
/// noise that trains the eye to skip this part of the screen.
class AlarmFatigueCard extends ConsumerWidget {
  const AlarmFatigueCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rollup = ref.watch(alarmFatigueProvider);
    return rollup.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (r) {
        if (r.total == 0) return const SizedBox.shrink();
        final delta = r.weekOverWeekDelta;
        // Only claim a direction when there IS one — "+0 vs last week" reads as a
        // finding when it is the absence of one.
        final trend = delta == 0
            ? 'same as last week'
            : delta > 0
                ? '$delta more than last week'
                : '${delta.abs()} fewer than last week';
        final overnightPct = (r.overnightShare * 100).round();
        final suggestion = alarmFatigueSuggestion(r);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r.total} alerts this week',
                    style: Theme.of(context).textTheme.titleSmall),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('$overnightPct% overnight · $trend',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final e in r.perCategory.entries)
                      Chip(label: Text('${e.key.label} ×${e.value}')),
                  ],
                ),
                if (suggestion != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(suggestion,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

