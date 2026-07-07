import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feedback/annotations.dart';
import '../logging/device_changes.dart';
import '../state/providers.dart';
import '../state/quick_log_service.dart';

/// One-tap logging for the things the models care about: carbs, an actual bolus,
/// exercise, alcohol, stress, and sensor/site changes. Everything here is persisted and
/// most items feed the retraining pipeline (context) or the timeline.
class QuickLogSheet extends ConsumerWidget {
  const QuickLogSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => const QuickLogSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.read(appJobsProvider);

    void toast(String msg) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick log', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip('🍽️ Carbs', () => _number(context, 'Carbs (g)', (v) async {
                      await jobs.logCarb(v);
                      toast('Logged ${v.toStringAsFixed(0)}g carbs.');
                    })),
                _Chip('💉 Bolus', () => _number(context, 'Units', (v) async {
                      await jobs.logBolus(v);
                      toast('Logged ${v.toStringAsFixed(1)}U bolus.');
                    }, decimal: true)),
                _Chip('🏃 Exercise', () async {
                  await jobs.logContext(AnnotationKind.exercise);
                  toast('Logged exercise.');
                }),
                _Chip('🍷 Alcohol', () async {
                  await jobs.logContext(AnnotationKind.alcohol,
                      window: const Duration(hours: 12));
                  toast('Logged alcohol — watch for delayed lows.');
                }),
                _Chip('😰 Stress', () async {
                  await jobs.logContext(AnnotationKind.stress);
                  toast('Logged stress.');
                }),
                _Chip('🙂 Mood', () => _mood(context, ref, toast)),
                _Chip('🤒 Illness', () => _illness(context, ref, toast)),
                _Chip('🩹 New sensor', () async {
                  await jobs.recordDeviceChange(DeviceKind.sensor);
                  toast('Sensor change recorded.');
                }),
                _Chip('🧷 New site', () async {
                  await jobs.recordDeviceChange(DeviceKind.site);
                  toast('Infusion site change recorded.');
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Quick illness on/off. Illness reliably raises insulin needs, so turning it on boosts
  /// the models and, on end, tags the sick period for retraining. (The app also auto-
  /// suggests this in Confirm events when your data looks illness-like.)
  Future<void> _illness(
      BuildContext context, WidgetRef ref, void Function(String) toast) async {
    final mode = ref.read(illnessModeProvider);
    if (mode.active) {
      final end = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Illness mode is on'),
          content: Text(
              'Boosting expected insulin needs ×${mode.expectedResistanceBoost.toStringAsFixed(2)}. '
              'End it once you\'re feeling better.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Keep on')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('End illness')),
          ],
        ),
      );
      if (end == true) {
        ref.read(quickLogServiceProvider).endIllness();
        toast('Illness mode ended.');
      }
      return;
    }
    // The widget only picks the option; the severity→boost policy lives in
    // QuickLogService (TASK-124).
    final severity = await showDialog<IllnessSeverity>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Feeling unwell?'),
        content: const Text(
            'Sick days usually raise insulin needs. Pick how rough you feel — the models '
            'expect more resistance while it\'s on, and today gets tagged for training.'),
        actions: [
          for (final s in IllnessSeverity.values)
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(s),
                child: Text(s.label)),
        ],
      ),
    );
    if (severity != null) {
      ref.read(quickLogServiceProvider).startIllness(severity);
      toast('Illness mode on — check ketones if high with normal IOB.');
    }
  }

  /// Log a wellbeing note (great/ok/low) as context.
  Future<void> _mood(
      BuildContext context, WidgetRef ref, void Function(String) toast) async {
    final level = await showDialog<MoodLevel>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How are you feeling?'),
        actions: [
          for (final m in MoodLevel.values)
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(m),
                child: Text(m.label)),
        ],
      ),
    );
    if (level != null) {
      await ref.read(quickLogServiceProvider).logMood(level);
      toast('Logged mood: ${level.note}.');
    }
  }

  Future<void> _number(
    BuildContext context,
    String label,
    Future<void> Function(double) onValue, {
    bool decimal = false,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(double.tryParse(controller.text)),
            child: const Text('Log'),
          ),
        ],
      ),
    );
    if (value != null && value > 0) await onValue(value);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      ActionChip(label: Text(label), onPressed: onTap);
}
