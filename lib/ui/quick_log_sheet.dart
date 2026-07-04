import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feedback/annotations.dart';
import '../logging/device_changes.dart';
import '../state/providers.dart';

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
