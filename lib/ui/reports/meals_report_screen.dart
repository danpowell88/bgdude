import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/units.dart';
import '../../reports/meals_report.dart';
import '../../state/providers.dart';
import 'report_range_picker.dart';

/// The Meals report: per-meal performance from confirmed, matured outcomes.
class MealsReportScreen extends ConsumerWidget {
  const MealsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(mealsReportProvider);
    final unit = ref.watch(glucoseUnitProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meals report')),
      body: Column(
        children: [
          const ReportRangePicker(),
          Expanded(
            child: !report.hasData
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No matured meal outcomes in this range yet. Log meals from '
                        'the library and they’ll appear here a few hours later.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _Body(report: report, unit: unit),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.report, required this.unit});
  final MealsReport report;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    String g(double mgdl) => Mgdl(mgdl).display(unit);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${report.totalOutcomes} meal outcomes',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('Average rise ${g(report.overallAvgExcursionMgdl)} ${unit.label} · '
                    'average pre-bolus ${report.overallAvgPreBolusMin.round()} min'),
              ],
            ),
          ),
        ),
        const _MovementCard(),
        const SizedBox(height: 8),
        Text('By meal (biggest rise first)',
            style: Theme.of(context).textTheme.titleSmall),
        for (final m in report.meals) _MealCard(m: m, unit: unit),
      ],
    );
  }
}

class _MovementCard extends ConsumerWidget {
  const _MovementCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(postMealMovementProvider).valueOrNull;
    if (r == null || !r.hasSignal) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.directions_walk),
            const SizedBox(width: 12),
            Expanded(child: Text(r.message)),
          ],
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.m, required this.unit});
  final MealPerformance m;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    String g(double mgdl) => Mgdl(mgdl).display(unit);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(m.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${m.name} · ${m.carbsGrams.round()}g',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text('×${m.count}',
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _chip('Rise', '+${g(m.avgExcursionMgdl)} ${unit.label}'),
                _chip('Peak at', '${m.avgTimeToPeakMin.round()} min'),
                _chip('>180', '${m.avgTimeAbove180Min.round()} min'),
                _chip('Pre-bolus', '${m.avgPreBolusMin.round()} min'),
                _chip('Settled', '${_signed(m.avgReturnDeltaMgdl, unit)} ${unit.label}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );

  static String _signed(double mgdl, GlucoseUnit unit) {
    final v = Mgdl(mgdl).inUnit(unit);
    final s = unit == GlucoseUnit.mmol ? v.toStringAsFixed(1) : v.round().toString();
    return v >= 0 ? '+$s' : s;
  }
}
