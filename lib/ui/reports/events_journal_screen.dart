import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reports/events_journal.dart';
import '../../state/providers.dart';
import 'report_range_picker.dart';

/// The Events journal: a filterable, newest-first timeline of confirmed events.
class EventsJournalScreen extends ConsumerStatefulWidget {
  const EventsJournalScreen({super.key});
  @override
  ConsumerState<EventsJournalScreen> createState() => _EventsJournalScreenState();
}

class _EventsJournalScreenState extends ConsumerState<EventsJournalScreen> {
  JournalCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eventsJournalProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Events journal')),
      body: Column(
        children: [
          const ReportRangePicker(),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final c in JournalCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.label),
                      selected: _filter == c,
                      onSelected: (_) => setState(() => _filter = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not build journal: $e')),
              data: (entries) {
                final shown = _filter == null
                    ? entries
                    : entries.where((e) => e.category == _filter).toList();
                if (shown.isEmpty) {
                  return const Center(
                      child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No events in this range.'),
                  ));
                }
                return ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) => _EntryTile(entry: shown[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(_icon(entry.category), color: _color(entry.category, context)),
      title: Text(entry.title),
      subtitle: entry.detail.isEmpty ? null : Text(entry.detail),
      trailing: Text(_fmt(entry.time),
          style: Theme.of(context).textTheme.bodySmall),
    );
  }

  static IconData _icon(JournalCategory c) => switch (c) {
        JournalCategory.annotation => Icons.edit_note,
        JournalCategory.pumpEvent => Icons.warning_amber_outlined,
        JournalCategory.deviceChange => Icons.healing,
        JournalCategory.lowEpisode => Icons.arrow_downward,
        JournalCategory.highEpisode => Icons.arrow_upward,
      };

  static Color? _color(JournalCategory c, BuildContext ctx) => switch (c) {
        JournalCategory.lowEpisode => Colors.red,
        JournalCategory.highEpisode => Colors.orange,
        _ => Theme.of(ctx).colorScheme.outline,
      };

  static String _fmt(DateTime d) =>
      '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
