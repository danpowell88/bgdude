import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/metrics.dart';
import '../core/samples.dart';
import '../insights/illness_mode.dart';
import '../insights/morning_summary.dart';
import '../state/providers.dart';

/// The unified Insights page: the daily briefing, insulin-sensitivity readiness,
/// illness mode, and model status — the things that used to be scattered across
/// separate screens, now read together the way they're actually used.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(dayDataProvider);
    final unit = ref.watch(glucoseUnitProvider);
    final ctx = ref.watch(effectiveSensitivityProvider);
    final features = ref.watch(contextFeaturesProvider);
    final illnessMode = ref.watch(illnessModeProvider);

    final overnight = _overnightMetrics(day.cgm);
    final summary = features == null
        ? null
        : MorningSummaryGenerator(unit: unit).generate(
            date: DateTime.now(),
            overnightMetrics: overnight,
            context: features,
            sensitivity: ctx,
          );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Daily briefing ---
        Text('Daily briefing', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_sunny_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summary?.headline ?? 'Connect data to see your briefing.',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                if (overnight.readingCount > 0) ...[
                  const SizedBox(height: 8),
                  Text('Overnight time in range: '
                      '${(overnight.timeInRange * 100).round()}%'),
                ],
              ],
            ),
          ),
        ),
        if (summary != null)
          for (final insight in summary.insights)
            Card(
              child: ListTile(
                leading: Icon(_severityIcon(insight.severity),
                    color: _severityColor(insight.severity, context)),
                title: Text(insight.title),
                subtitle: Text(insight.detail),
              ),
            ),

        const SizedBox(height: 16),
        // --- Sensitivity readiness ---
        Text('Insulin sensitivity',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _SensitivityCard(mult: ctx.effectiveMultiplier, reasons: ctx.reasons),

        const SizedBox(height: 16),
        // --- Illness mode (inline) ---
        Text('Illness mode', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Sick day mode'),
                subtitle: Text(illnessMode.active
                    ? 'Active — boosting expected insulin needs ×'
                        '${illnessMode.expectedResistanceBoost.toStringAsFixed(2)}'
                    : 'Raises expected insulin needs and tags today for the models'),
                value: illnessMode.active,
                onChanged: (v) {
                  final n = ref.read(illnessModeProvider.notifier);
                  v ? n.activate() : n.deactivate();
                },
              ),
              if (illnessMode.active)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      const Text('Resistance'),
                      Expanded(
                        child: Slider(
                          value: illnessMode.expectedResistanceBoost,
                          min: IllnessMode.minBoost,
                          max: IllnessMode.maxBoost,
                          divisions: 10,
                          label:
                              '×${illnessMode.expectedResistanceBoost.toStringAsFixed(2)}',
                          onChanged: (v) => ref
                              .read(illnessModeProvider.notifier)
                              .updateBoost(v),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // --- Model status ---
        Text('Models', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.psychology),
            title: Text('BG forecaster'),
            subtitle: Text(
                'Deterministic baseline active; a learned personal correction trains '
                'overnight once ~2 weeks of data pass the safety gate.'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.tune),
            title: Text('Sensitivity model'),
            subtitle: Text(
                'Learns how sleep, HRV, exercise, cycle and illness shift your '
                'insulin needs. Uses a transparent heuristic until trained.'),
          ),
        ),
      ],
    );
  }

  GlucoseMetrics _overnightMetrics(List<CgmSample> cgm) {
    final overnight =
        cgm.where((s) => s.time.hour >= 0 && s.time.hour < 7).toList();
    return const MetricsCalculator()
        .compute(overnight.isEmpty ? cgm : overnight);
  }

  static IconData _severityIcon(InsightSeverity s) => switch (s) {
        InsightSeverity.info => Icons.info_outline,
        InsightSeverity.notable => Icons.priority_high,
        InsightSeverity.caution => Icons.warning_amber,
      };

  static Color _severityColor(InsightSeverity s, BuildContext context) =>
      switch (s) {
        InsightSeverity.info => Theme.of(context).colorScheme.primary,
        InsightSeverity.notable => Colors.orange,
        InsightSeverity.caution => Colors.red,
      };
}

class _SensitivityCard extends StatelessWidget {
  const _SensitivityCard({required this.mult, required this.reasons});
  final double mult;
  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    final pct = ((mult - 1) * 100).round();
    final label = pct.abs() < 3
        ? 'Typical for you today'
        : pct > 0
            ? '~$pct% more insulin-resistant today'
            : '~${pct.abs()}% more insulin-sensitive today';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            if (reasons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  children: [for (final r in reasons) Chip(label: Text(r))],
                ),
              ),
            const SizedBox(height: 6),
            Text('Dosing math scales by ×${mult.toStringAsFixed(2)} accordingly.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
