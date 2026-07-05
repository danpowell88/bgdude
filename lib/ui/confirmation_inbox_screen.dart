import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feedback/pending_confirmation.dart';
import '../state/providers.dart';

/// The Confirmation Inbox: review detected events and confirm, edit, or dismiss them.
/// Confirming builds the "real & confirmed" data that reports and the model rely on.
class ConfirmationInboxScreen extends ConsumerWidget {
  const ConfirmationInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingConfirmationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm events')),
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not scan history: $e')),
        data: (items) => items.isEmpty
            ? const _AllCaughtUp()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Confirming these keeps your stats and the model honest — '
                      'they’ll count as real, confirmed data in reports.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  for (final p in items) _ConfirmationCard(item: p),
                ],
              ),
      ),
    );
  }
}

class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('All caught up — nothing to confirm right now.',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationCard extends ConsumerWidget {
  const _ConfirmationCard({required this.item});
  final PendingConfirmation item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.read(appJobsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon(item.type)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text('${(item.confidence * 100).round()}%',
                    style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text('${_when(item.start)} · ${item.detail}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => jobs.dismissPending(item),
                  child: const Text('Dismiss'),
                ),
                if (item.type == ConfirmationType.unannouncedMeal)
                  TextButton(
                    onPressed: () => _editThenConfirm(context, jobs),
                    child: const Text('Edit'),
                  ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () => jobs.confirmPending(item),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editThenConfirm(BuildContext context, AppJobs jobs) async {
    final controller = TextEditingController(
        text: (item.carbsGrams ?? 0).round().toString());
    final grams = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm carbs'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Carbs (g)', suffixText: 'g'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text) ?? 0),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (grams != null && grams > 0) {
      await jobs.confirmPending(item, carbsGrams: grams);
    }
  }

  static IconData _icon(ConfirmationType t) => switch (t) {
        ConfirmationType.unannouncedMeal => Icons.restaurant,
        ConfirmationType.compressionLow => Icons.bedtime_outlined,
        ConfirmationType.illness => Icons.sick_outlined,
        ConfirmationType.siteFailure => Icons.healing,
      };

  static String _when(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
