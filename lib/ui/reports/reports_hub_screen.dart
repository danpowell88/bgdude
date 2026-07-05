import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import 'glucose_report_screen.dart';

/// Hub for the reporting section. Currently the Glucose report; insulin, meals, therapy
/// and correlation reports slot in here as they land.
class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glucose = ref.watch(glucoseReportProvider);
    final summary = glucose.maybeWhen(
      data: (b) => b.report.hasData
          ? 'TIR ${(b.report.metrics.timeInRange * 100).round()}% · '
              'GMI ${b.report.metrics.gmi.toStringAsFixed(1)}% · '
              '${b.report.daysWithData} days'
          : 'No confirmed data in range yet',
      orElse: () => 'Tap to view',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Glucose report'),
              subtitle: Text(summary),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const GlucoseReportScreen()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Reports use real, confirmed data — sensor artifacts you\'ve marked are '
              'excluded. Insulin, meals, therapy and lifestyle-correlation reports are '
              'on the way.',
            ),
          ),
        ],
      ),
    );
  }
}
