import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import 'correlation_report_screen.dart';
import 'events_journal_screen.dart';
import 'glucose_report_screen.dart';
import 'insulin_report_screen.dart';
import 'meals_report_screen.dart';
import 'model_report_screen.dart';
import 'therapy_report_screen.dart';

/// Hub for the reporting section. Currently the Glucose report; insulin, meals, therapy
/// and correlation reports slot in here as they land.
class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glucose = ref.watch(glucoseReportProvider);
    final glucoseSummary = glucose.maybeWhen(
      data: (b) => b.report.hasData
          ? 'TIR ${(b.report.metrics.timeInRange * 100).round()}% · '
              'GMI ${b.report.metrics.gmi.toStringAsFixed(1)}% · '
              '${b.report.daysWithData} days'
          : 'No confirmed data in range yet',
      orElse: () => 'Tap to view',
    );
    final insulin = ref.watch(insulinReportProvider);
    final insulinSummary = insulin.maybeWhen(
      data: (r) => r.hasData
          ? 'Avg TDD ${r.avgTdd.toStringAsFixed(1)} U · '
              '${(r.basalFraction * 100).round()}% basal'
          : 'No insulin history in range yet',
      orElse: () => 'Tap to view',
    );
    final meals = ref.watch(mealsReportProvider);
    final mealsSummary = meals.hasData
        ? '${meals.totalOutcomes} outcomes · avg pre-bolus '
            '${meals.overallAvgPreBolusMin.round()} min'
        : 'No matured meal outcomes yet';

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _ReportCard(
            icon: Icons.show_chart,
            title: 'Glucose report',
            subtitle: glucoseSummary,
            builder: () => const GlucoseReportScreen(),
          ),
          _ReportCard(
            icon: Icons.medication_liquid_outlined,
            title: 'Insulin report',
            subtitle: insulinSummary,
            builder: () => const InsulinReportScreen(),
          ),
          _ReportCard(
            icon: Icons.restaurant_outlined,
            title: 'Meals report',
            subtitle: mealsSummary,
            builder: () => const MealsReportScreen(),
          ),
          _ReportCard(
            icon: Icons.tune,
            title: 'Therapy report',
            subtitle: 'Learned sensitivity trend & basal suggestions',
            builder: () => const TherapyReportScreen(),
          ),
          _ReportCard(
            icon: Icons.insights_outlined,
            title: 'Correlations',
            subtitle: 'Glucose vs sleep, exercise, HRV & resting HR',
            builder: () => const CorrelationReportScreen(),
          ),
          _ReportCard(
            icon: Icons.event_note_outlined,
            title: 'Events journal',
            subtitle: 'Confirmed notes, pump events, changes & episodes',
            builder: () => const EventsJournalScreen(),
          ),
          _ReportCard(
            icon: Icons.model_training,
            title: 'Model performance',
            subtitle: 'Forecast accuracy, error grid & calibration',
            builder: () => const ModelReportScreen(),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Reports use real, confirmed data — sensor artifacts you\'ve marked are '
              'excluded.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => builder())),
      ),
    );
  }
}
