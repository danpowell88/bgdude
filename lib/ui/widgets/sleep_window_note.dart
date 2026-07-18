/// Explains Control-IQ's tighter overnight target (issue #87).
///
/// The shading on the chart says *when*; this says *why it matters*. Without it the
/// flatter overnight trace and the different response to a correction look like the
/// forecast misbehaving rather than the pump doing its job.
library;

import 'package:flutter/material.dart';

import '../../pump/sleep_schedule.dart';

class SleepWindowNote extends StatelessWidget {
  const SleepWindowNote({
    super.key,
    required this.schedules,
    required this.now,
  });

  final List<SleepSchedule> schedules;
  final DateTime now;

  /// Whether [now] falls inside any window. Exposed so the copy can be checked
  /// without building a widget tree.
  @visibleForTesting
  static bool isAsleepAt(List<SleepSchedule> schedules, DateTime now) =>
      sleepWindowsInRange(schedules, now, -1, 1)
          .any((w) => w.startMinutesFromNow <= 0 && w.endMinutesFromNow >= 0);

  @override
  Widget build(BuildContext context) {
    // No schedules at all: say nothing rather than assert Control-IQ never sleeps —
    // an unread pump and a pump with sleep off are not the same claim, and the caller
    // passes an empty list for both.
    if (schedules.isEmpty) return const SizedBox.shrink();

    final asleep = isAsleepAt(schedules, now);
    final windows = schedules.map((s) => s.label).join(', ');
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.bedtime_outlined, color: cs.tertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                asleep
                    ? 'Control-IQ is in sleep mode now ($windows). It aims at a '
                        'tighter target overnight and gives no automatic correction '
                        'boluses, so the line ahead is usually flatter than by day.'
                    : 'Control-IQ sleep runs $windows (shaded). In that window it '
                        'aims at a tighter target and gives no automatic correction '
                        'boluses.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
