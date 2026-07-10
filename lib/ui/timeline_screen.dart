import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feedback/annotations.dart';
import '../insights/reading_explainer.dart';
import '../state/providers.dart';
import '../timeline/day_event.dart';
import 'explain_reading_screen.dart';
import '../core/time_format.dart';
import '../core/sleep_window.dart';

/// The day "stream": every event from today on one page. The user reviews each and
/// tags whether the models should use it or ignore it (compression low, new sensor,
/// new site, illness…). Tagging ignore writes an annotation the retraining pipeline
/// already knows how to exclude/relabel.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(dayEventsProvider);

    if (events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No events yet today. As meals, boluses and glucose swings happen '
            'they\'ll appear here for you to review.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Newest first.
    final ordered = [...events]..sort((a, b) => b.time.compareTo(a.time));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: ordered.length,
      itemBuilder: (context, i) => TimelineEventCard(event: ordered[i]),
    );
  }
}

/// One event in the day stream, with explain + tag actions. Reused inline on the Today
/// tab and in the full [TimelineScreen].
class TimelineEventCard extends ConsumerWidget {
  const TimelineEventCard({super.key, required this.event});
  final DayEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ignored = event.disposition == ModelDisposition.ignore;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.type.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        '${formatHhmm(event.time)} · ${event.type.label}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                ),
                _DispositionChip(event: event),
              ],
            ),
            const SizedBox(height: 8),
            Text(event.detail),
            const SizedBox(height: 8),
            Row(
              children: [
                if (event.explainable)
                  TextButton.icon(
                    onPressed: () => explainDayEvent(context, ref, event),
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('Explain'),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _tag(context, ref),
                  icon: Icon(ignored ? Icons.visibility_off : Icons.tune,
                      size: 18),
                  label: Text(ignored ? 'Ignored' : 'Use for model'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tag(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(eventDispositionProvider.notifier);
    // A contextual header explaining the smart default for this event type.
    final String header = event.type.isPumpSourced
        ? 'Pump dosing data — used to train the model by default.'
        : event.type.defaultDisposition == ModelDisposition.ignore
            ? 'Suspected ${event.type.label.toLowerCase()} — excluded from the model by '
                'default. Override below if it was real.'
            : 'Real signal — used to train the model by default.';
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(header, style: Theme.of(context).textTheme.bodySmall),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Use for model'),
              subtitle: const Text('This is real signal — train on it'),
              onTap: () {
                notifier.use(event.id);
                Navigator.of(context).pop();
              },
            ),
            const Divider(height: 1),
            // Only reasons that make sense for this event type (a compression low is
            // never "missed carbs"; pump dosing isn't a CGM artefact).
            for (final reason in event.type.relevantReasons)
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: Text('Ignore — ${reason.label}'),
                onTap: () {
                  notifier.ignore(event.id, reason);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Explains a [DayEvent] (a specific past high/low/detected event), pushing
/// [ExplainReadingScreen] for it. Shared by [TimelineEventCard]'s "Explain" button
/// and any chart's event-marker overlay (TASK-155) — tapping a marker for an
/// explainable event should behave exactly like tapping "Explain" in the day
/// stream, including auto-tagging the event ignore when an exclusion reason is
/// accepted.
Future<void> explainDayEvent(
    BuildContext context, WidgetRef ref, DayEvent event) async {
  final day = ref.read(dayDataProvider);
  final explanations = ReadingExplainer().explain(
    at: event.time,
    cgm: day.cgm,
    boluses: day.boluses,
    basal: day.basal,
    carbs: day.carbs,
    settings: day.settings,
    wasAsleep: event.type == DayEventType.compressionLow ||
        defaultAsleepAt(event.time),
  );
  if (!context.mounted) return;
  final annotation = await Navigator.of(context).push<Annotation>(
    MaterialPageRoute<Annotation>(
      builder: (_) => ExplainReadingScreen(
        at: event.time,
        mgdl: event.mgdl ?? 0,
        explanations: explanations,
      ),
    ),
  );
  // Accepting an explanation with an exclusion kind marks the event ignore.
  if (annotation != null) {
    final reason = _reasonFor(annotation.kind);
    if (reason != null) {
      ref.read(eventDispositionProvider.notifier).ignore(event.id, reason);
    }
  }
}

IgnoreReason? _reasonFor(AnnotationKind annotationKind) {
  final name = annotationKind.name;
  if (name.contains('compressionLow')) return IgnoreReason.compressionLow;
  if (name.contains('siteFailure')) return IgnoreReason.siteFailure;
  if (name.contains('sensorWarmup')) return IgnoreReason.sensorWarmup;
  if (name.contains('illness')) return IgnoreReason.illness;
  if (name.contains('missedCarbs')) return IgnoreReason.missedCarbs;
  return null;
}

class _DispositionChip extends StatelessWidget {
  const _DispositionChip({required this.event});
  final DayEvent event;

  @override
  Widget build(BuildContext context) {
    if (event.disposition == ModelDisposition.use) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return Chip(
      label: Text(event.ignoreReason?.label ?? 'Ignored'),
      visualDensity: VisualDensity.compact,
      avatar: const Icon(Icons.visibility_off, size: 16),
      backgroundColor: cs.surfaceContainerHighest,
    );
  }
}
