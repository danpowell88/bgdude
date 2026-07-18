import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/metrics.dart';
import '../core/samples.dart';
import '../insights/lab_a1c.dart';
import '../insights/morning_summary.dart';
import '../state/providers.dart';
import 'widgets/alarm_fatigue_card.dart';

/// The unified Insights page: the daily briefing, insulin-sensitivity readiness, and
/// model status — the things that used to be scattered across separate screens, now read
/// together the way they're actually used. (Illness is auto-suggested in Confirm events
/// and toggled from Quick-log, so it no longer lives here.)
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(dayDataProvider);
    final unit = ref.watch(glucoseUnitProvider);
    final ctx = ref.watch(effectiveSensitivityProvider);
    final features = ref.watch(contextFeaturesProvider);

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
        const AlarmFatigueCard(),

        const SizedBox(height: 16),
        // --- A1c / GMI goal ---
        Text('A1c goal', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ref.watch(a1cStatusProvider).when(
              loading: () => const Card(
                  child: ListTile(title: Text('Calculating GMI…'))),
              error: (e, _) => const SizedBox.shrink(),
              data: (s) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(s.onTrack ? Icons.check_circle : Icons.flag_outlined,
                              color: s.onTrack ? Colors.green : Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s.summary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('Goal: ${s.targetGmiPercent.toStringAsFixed(1)}% GMI'),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _editGoal(context, ref, s.targetGmiPercent),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        const SizedBox(height: 8),
        const _LabA1cSection(),

        const SizedBox(height: 16),
        // --- Sleep & glucose ---
        Text('Sleep & glucose', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ref.watch(sleepInsightProvider).when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (s) => Card(
                child: ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: Text(s.message),
                ),
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

  Future<void> _editGoal(
      BuildContext context, WidgetRef ref, double current) async {
    final controller =
        TextEditingController(text: current.toStringAsFixed(1));
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('A1c / GMI goal (%)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Target GMI %'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (v != null && v > 4 && v < 14) {
      await ref.read(a1cTargetProvider.notifier).save(v);
    }
  }

  GlucoseMetrics _overnightMetrics(List<CgmSample> cgm) {
    // Last night's window (23:00 yesterday → 07:00 today), not any-hour-<7 across 24h.
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final start = midnight.subtract(const Duration(hours: 1));
    final end = midnight.add(const Duration(hours: 7));
    final overnight = [
      for (final s in cgm)
        if (!s.time.isBefore(start) && s.time.isBefore(end)) s,
    ];
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

/// Log a lab HbA1c and show its discordance with the CGM-derived GMI.
class _LabA1cSection extends ConsumerWidget {
  const _LabA1cSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gap = ref.watch(glycationGapProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_outlined),
                const SizedBox(width: 8),
                const Expanded(child: Text('Lab A1c vs GMI')),
                TextButton(
                  onPressed: () => _logLabA1c(context, ref),
                  child: const Text('Log lab A1c'),
                ),
              ],
            ),
            if (gap != null) ...[
              const SizedBox(height: 6),
              Text(gap.message,
                  style: Theme.of(context).textTheme.bodySmall),
            ] else
              Text('Enter a recent lab HbA1c to compare it with your CGM GMI.',
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _logLabA1c(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log lab A1c'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration:
              const InputDecoration(labelText: 'HbA1c', suffixText: '%'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null && value > 3 && value < 20) {
      await ref
          .read(labA1cProvider.notifier)
          .add(LabA1c(percent: value, date: DateTime.now()));
    }
  }
}
