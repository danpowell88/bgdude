import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../insights/illness_mode.dart';
import '../state/providers.dart';

/// Illness ("sick day") mode: activation toggle with a resistance-boost slider, a
/// standing sick-day checklist, and — when the detector has flagged illness-like data —
/// a suggestion banner. State lives in [illnessModeProvider].
class IllnessScreen extends ConsumerWidget {
  const IllnessScreen({super.key, this.suggestion});

  /// Pending detector suggestion, if any (passed by the caller that ran detection).
  final IllnessSuggestion? suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(illnessModeProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Illness mode')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (suggestion != null && suggestion!.suggestActivation && !mode.active)
            Card(
              color: cs.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your data looks illness-like',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    for (final r in suggestion!.reasons) Text('• $r'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Not sick'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => ref
                              .read(illnessModeProvider.notifier)
                              .activate(),
                          child: const Text('Turn on illness mode'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          SwitchListTile(
            title: const Text('Illness mode'),
            subtitle: Text(mode.active
                ? 'Active${_activeFor(context, mode)}'
                : 'Boosts expected insulin needs and tags this period for the models'),
            value: mode.active,
            onChanged: (v) {
              final notifier = ref.read(illnessModeProvider.notifier);
              if (v) {
                notifier.activate();
              } else {
                notifier.deactivate();
              }
            },
          ),
          if (mode.active) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Expected resistance: ×${mode.expectedResistanceBoost.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Slider(
                    value: mode.expectedResistanceBoost,
                    min: IllnessMode.minBoost,
                    max: IllnessMode.maxBoost,
                    divisions: 10,
                    label: '×${mode.expectedResistanceBoost.toStringAsFixed(2)}',
                    onChanged: (v) =>
                        ref.read(illnessModeProvider.notifier).updateBoost(v),
                  ),
                  Text(
                    'Applied on top of today\'s sensitivity context — the bolus '
                    'advisor and predictions run stronger while this is on.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Sick-day checklist',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChecklistItem('Never stop basal insulin, even if not eating.'),
                  _ChecklistItem(
                      'Check ketones when above 14 mmol/L (250 mg/dL), and every '
                      '4–6 h while unwell.'),
                  _ChecklistItem('Drink water steadily — dehydration drives '
                      'glucose and ketones up.'),
                  _ChecklistItem('Correct more often; illness typically raises '
                      'insulin needs 20–50%.'),
                  _ChecklistItem(
                      'Seek urgent care for moderate/large ketones with vomiting, '
                      'or if you can\'t keep fluids down.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _activeFor(BuildContext context, IllnessMode mode) {
    final started = mode.startedAt;
    if (started == null) return '';
    final d = DateTime.now().difference(started);
    if (d.inHours < 1) return ' · ${d.inMinutes} min';
    if (d.inHours < 48) return ' · ${d.inHours} h';
    return ' · ${d.inDays} days';
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
