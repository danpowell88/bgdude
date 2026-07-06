import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/time_format.dart';
import '../core/units.dart';
import '../insights/exercise_mode.dart';
import '../insights/workout_classifier.dart';
import '../state/providers.dart';

/// Announce a workout so the app can be proactive: raise the low-alert threshold for the
/// session + tail, suggest a pre-exercise snack, and arm the overnight-low watch.
class ExerciseModeScreen extends ConsumerStatefulWidget {
  const ExerciseModeScreen({super.key});
  @override
  ConsumerState<ExerciseModeScreen> createState() => _ExerciseModeScreenState();
}

class _ExerciseModeScreenState extends ConsumerState<ExerciseModeScreen> {
  WorkoutType _type = WorkoutType.aerobic;
  int _durationMinutes = 45;
  int _startOffsetMinutes = 0;

  static const _types = [
    (WorkoutType.aerobic, 'Aerobic (cardio)'),
    (WorkoutType.resistance, 'Resistance (weights)'),
    (WorkoutType.mixed, 'Mixed / HIIT'),
  ];

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(exercisePlanProvider);
    final unit = ref.watch(glucoseUnitProvider);
    final state = ref.watch(livePredictionStateProvider);
    final snap = ref.watch(pumpSnapshotProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise mode')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (active != null && active.affectsAt(DateTime.now()))
            _ActiveCard(plan: active, onEnd: () {
              ref.read(appJobsProvider).endExercise();
              setState(() {});
            })
          else ...[
            Text('Announce a workout',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<WorkoutType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final (t, label) in _types)
                  DropdownMenuItem(value: t, child: Text(label)),
              ],
              onChanged: (v) => setState(() => _type = v ?? WorkoutType.aerobic),
            ),
            const SizedBox(height: 16),
            _Stepper(
              label: 'Duration',
              value: '$_durationMinutes min',
              onMinus: _durationMinutes > 15
                  ? () => setState(() => _durationMinutes -= 15)
                  : null,
              onPlus: _durationMinutes < 180
                  ? () => setState(() => _durationMinutes += 15)
                  : null,
            ),
            const SizedBox(height: 8),
            Text('Starting', style: Theme.of(context).textTheme.bodyMedium),
            Wrap(
              spacing: 8,
              children: [
                for (final (mins, label) in const [
                  (0, 'Now'),
                  (15, 'In 15m'),
                  (30, 'In 30m'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _startOffsetMinutes == mins,
                    onSelected: (_) =>
                        setState(() => _startOffsetMinutes = mins),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (state != null)
              _PrepCard(
                prep: const ExerciseModeCoach().prep(
                  currentMgdl: state.currentMgdl,
                  iobUnits: snap?.iobUnits ?? 0,
                  rocMgdlPerMin: state.recentRocMgdlPerMin,
                  type: _type,
                ),
                unit: unit,
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.directions_run),
              label: const Text('Start exercise mode'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(appJobsProvider).announceExercise(ExercisePlan(
                      startAt: DateTime.now()
                          .add(Duration(minutes: _startOffsetMinutes)),
                      durationMinutes: _durationMinutes,
                      type: _type,
                    ));
                messenger.showSnackBar(const SnackBar(
                    content: Text('Exercise mode on — low alerts will lead '
                        'earlier during and after.')));
                setState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.plan, required this.onEnd});
  final ExercisePlan plan;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.directions_run),
              const SizedBox(width: 8),
              Text('Exercise mode on',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            Text('Low alerts lead earlier until ${formatHhmm(plan.effectEnd)} '
                '(session + recovery tail).'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onEnd, child: const Text('End exercise mode')),
          ],
        ),
      ),
    );
  }

}

class _PrepCard extends StatelessWidget {
  const _PrepCard({required this.prep, required this.unit});
  final ExercisePrep prep;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(prep.suggestedCarbsGrams > 0
                ? Icons.cookie_outlined
                : Icons.check_circle_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(prep.message)),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
            icon: const Icon(Icons.remove_circle_outline), onPressed: onMinus),
        SizedBox(width: 84, child: Text(value, textAlign: TextAlign.center)),
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: onPlus),
      ],
    );
  }
}
