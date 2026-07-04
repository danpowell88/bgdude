import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/predictor.dart';
import '../core/samples.dart';
import '../core/units.dart';
import '../meals/prebolus_coach.dart';
import '../state/providers.dart';

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
    final snapshot = ref.watch(pumpSnapshotProvider).valueOrNull;
    final cs = Theme.of(context).colorScheme;

    PreBolusAdvice? advice;
    final mgdl = snapshot?.cgmMgdl?.toDouble();
    if (mgdl != null) {
      final state = PredictionState(
        now: snapshot!.cgmTime ?? DateTime.now(),
        currentMgdl: mgdl,
        recentRocMgdlPerMin:
            (snapshot.cgmTrend ?? GlucoseTrend.flat).mgdlPerMin,
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: ref.watch(therapySettingsProvider),
        context: ref.watch(sensitivityContextProvider),
      );
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
          if (advice != null) _CoachCard(advice: advice, ref: ref, meal: meal),
          if (advice == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Pre-bolus coaching needs a live CGM reading — '
                    'connect the pump first.'),
              ),
            ),
          const SizedBox(height: 16),
          Text('Learned curve', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(context, 'Carbs', '${meal.carbsGrams.toStringAsFixed(0)} g'),
                  _kv(context, 'Absorption', '~${meal.absorptionMinutes} min'),
                  _kv(context, 'BG peak', '~+${meal.peakOffsetMinutes} min'),
                  _kv(context, 'Fat/protein heavy',
                      meal.fatProteinHeavy ? 'yes' : 'no'),
                  _kv(context, 'Logged outcomes', '${meal.outcomes.length}'),
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

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 150, child: Text(k)),
            Expanded(
              child: Text(v,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.advice, required this.ref, required this.meal});
  final PreBolusAdvice advice;
  final WidgetRef ref;
  final dynamic meal;

  @override
  Widget build(BuildContext context) {
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
            for (final step in advice.working)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 110,
                        child: Text(step.label,
                            style: Theme.of(context).textTheme.bodySmall)),
                    Expanded(child: Text(step.value)),
                  ],
                ),
              ),
            for (final note in advice.notes)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(note,
                            style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
              ),
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
                          meal.name as String,
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
