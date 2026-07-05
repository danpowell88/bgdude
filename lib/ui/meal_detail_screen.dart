import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/units.dart';
import '../meals/fpu_coach.dart';
import '../meals/meal_library.dart';
import '../meals/prebolus_coach.dart';
import '../state/providers.dart';
import 'widgets/common.dart';

/// A saved meal's detail view: learned-curve stats, outcome-derived insights, and the
/// pre-bolus coach card computed from the live pump state.
class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({super.key, required this.mealId});

  final String mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(mealLibraryProvider);
    final meal = library.findById(mealId);
    if (meal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Meal not found')),
      );
    }

    final unit = ref.watch(glucoseUnitProvider);
    final insights = library.mealInsights(meal);
    final cs = Theme.of(context).colorScheme;

    PreBolusAdvice? advice;
    final state = ref.watch(livePredictionStateProvider);
    if (state != null) {
      advice = ref.watch(preBolusCoachProvider).advise(
            meal: meal,
            state: state,
            displayUnit: unit,
          );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${meal.emoji} ${meal.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.tonalIcon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await ref.read(appJobsProvider).logMeal(
                    meal: meal,
                    preBolusMinutes: advice?.recommendedMinutes ?? 0,
                    bolusUnits: 0,
                  );
              messenger.showSnackBar(const SnackBar(
                content: Text('Logged — the app will learn from how it plays out '
                    'over the next few hours.'),
              ));
            },
            icon: const Icon(Icons.restaurant),
            label: const Text('Log this meal (ate now)'),
          ),
          const SizedBox(height: 12),
          if (advice != null) _CoachCard(advice: advice, meal: meal),
          if (advice == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Pre-bolus coaching needs a live CGM reading — '
                    'connect the pump first.'),
              ),
            ),
          _FpuCard(meal: meal),
          const SizedBox(height: 16),
          Text('Learned curve', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KvRow('Carbs', '${meal.carbsGrams.toStringAsFixed(0)} g'),
                  KvRow('Absorption', '~${meal.absorptionMinutes} min'),
                  KvRow('BG peak', '~+${meal.peakOffsetMinutes} min'),
                  KvRow('Fat/protein heavy',
                      meal.fatProteinHeavy ? 'yes' : 'no'),
                  KvRow('Logged outcomes', '${meal.outcomes.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('What this meal does to you',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final insight in insights)
            Card(
              child: ListTile(
                leading: const Icon(Icons.insights),
                title: Text(insight),
              ),
            ),
          if (meal.outcomes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Recent outcomes',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final o in meal.outcomes.reversed.take(5))
              Card(
                child: ListTile(
                  dense: true,
                  title: Text(
                    'Peak ${Mgdl(o.peakMgdl).display(unit)} ${unit.label} '
                    'at +${o.peakOffsetMinutes} min',
                  ),
                  subtitle: Text(
                    '${_date(o.eatenAt)} · pre-bolus ${o.preBolusMinutes} min · '
                    '${o.bolusUnits.toStringAsFixed(1)} U',
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            'Log this meal from the bolus advisor when you eat it; outcomes are '
            'computed from CGM three hours later and refine the curve.',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime t) =>
      '${t.day}/${t.month}/${t.year % 100}';
}

/// Fat-protein-unit dosing help for meals with macros (or flagged fat/protein-heavy).
class _FpuCard extends ConsumerWidget {
  const _FpuCard({required this.meal});
  final SavedMeal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const coach = FpuCoach();
    if (!coach.warrantsSplit(
      fatGrams: meal.fatGrams,
      proteinGrams: meal.proteinGrams,
      fatProteinHeavy: meal.fatProteinHeavy,
    )) {
      return const SizedBox.shrink();
    }
    final settings = ref.watch(therapySettingsProvider);
    final icr = settings.segmentAt(DateTime.now()).carbRatio;
    final hasMacros = meal.fatGrams > 0 || meal.proteinGrams > 0;
    final a = coach.advise(
      carbsGrams: meal.carbsGrams,
      fatGrams: meal.fatGrams,
      proteinGrams: meal.proteinGrams,
      insulinToCarbRatio: icr,
    );
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.hourglass_bottom),
              const SizedBox(width: 8),
              Text('Fat/protein — extend the dose',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            if (hasMacros && a.recommendSplit) ...[
              Text('${a.fpu.toStringAsFixed(1)} fat-protein units. Consider splitting: '
                  '~${a.immediateUnits.toStringAsFixed(1)} U now for carbs and '
                  '~${a.extendedUnits.toStringAsFixed(1)} U extended over '
                  '${a.extendHours} h.'),
              const SizedBox(height: 6),
            ],
            Text(
              'This meal tends to raise glucose late — watch for a delayed rise '
              '${a.delayedRiseFromHours}–${a.delayedRiseToHours} h after eating. An '
              'extended/split bolus handles it better than one up-front dose.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachCard extends ConsumerWidget {
  const _CoachCard({required this.advice, required this.meal});
  final PreBolusAdvice advice;
  final SavedMeal meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final headline = advice.bolusAfterEating
        ? 'Eat first — bolus with or after the meal'
        : advice.recommendedMinutes == 0
            ? 'Bolus and eat together'
            : 'Bolus ${advice.recommendedMinutes} min before eating';

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, color: cs.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(headline,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: cs.onPrimaryContainer)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AdviceWorkingList(advice.working),
            if (advice.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              AdviceNotesList(advice.notes),
            ],
            if (!advice.bolusAfterEating && advice.recommendedMinutes > 0) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await ref
                        .read(notificationServiceProvider)
                        .schedulePreBolusTimer(
                          Duration(minutes: advice.recommendedMinutes),
                          meal.name,
                        );
                    messenger.showSnackBar(SnackBar(
                      content: Text('Timer set — you\'ll be nudged in '
                          '${advice.recommendedMinutes} min.'),
                    ));
                  },
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Start pre-bolus timer'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
