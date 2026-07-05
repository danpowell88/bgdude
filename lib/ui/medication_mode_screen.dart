import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../insights/medication_mode.dart';
import '../state/providers.dart';

/// Steroid / medication mode: while a course is active, insulin needs are raised across
/// the app (dosing suggestions, expectations). Advisory only.
class MedicationModeScreen extends ConsumerWidget {
  const MedicationModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(medicationModeProvider);
    final notifier = ref.read(medicationModeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Medication / steroid mode')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Glucocorticoids (steroids) raise insulin needs, often a lot. Turn this on '
            'while you\'re on a course and the app will expect more resistance in its '
            'sensitivity, dosing hints and insights. It never changes your pump.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            color: mode.active
                ? Theme.of(context).colorScheme.tertiaryContainer
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Medication mode'),
                    subtitle: Text(mode.active
                        ? 'On — ${mode.intensity.label.toLowerCase()} '
                            '(+${((mode.intensity.resistanceBoost - 1) * 100).round()}% '
                            'resistance)'
                        : 'Off'),
                    value: mode.active,
                    onChanged: (v) =>
                        v ? notifier.start(mode.intensity) : notifier.stop(),
                  ),
                  const Divider(),
                  const Text('Intensity'),
                  const SizedBox(height: 8),
                  SegmentedButton<MedicationIntensity>(
                    segments: [
                      for (final i in MedicationIntensity.values)
                        ButtonSegment(value: i, label: Text(i.label)),
                    ],
                    selected: {mode.intensity},
                    onSelectionChanged: (s) {
                      final intensity = s.first;
                      if (mode.active) {
                        notifier.start(intensity, name: mode.name);
                      } else {
                        notifier.setIntensity(intensity);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
