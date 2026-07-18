/// Which pump history events bgdude understands (issue #94).
///
/// Lives under Developer next to the Protocol Explorer: when something unexplained
/// turns up in the history, this answers "does the app even know what that event is?"
/// without a rebuild or a look at the source.
library;

import 'package:flutter/material.dart';

import '../pump/history_log_coverage.dart';

class HistoryCoverageScreen extends StatefulWidget {
  const HistoryCoverageScreen({super.key});

  @override
  State<HistoryCoverageScreen> createState() => _HistoryCoverageScreenState();
}

class _HistoryCoverageScreenState extends State<HistoryCoverageScreen> {
  String _filter = '';
  bool _decodedOnly = false;

  @override
  Widget build(BuildContext context) {
    final decoded = decodedHistoryLogCount;
    final total = historyLogTypes.length;
    final theme = Theme.of(context);

    final shown = [
      for (final t in historyLogTypes)
        if ((!_decodedOnly || t.decoded) &&
            (_filter.isEmpty ||
                t.name.toLowerCase().contains(_filter.toLowerCase())))
          t,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('History decode coverage')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$decoded of $total event types decoded',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Undecoded events still stream from the pump — they just are not '
                  'turned into therapy data. This list is generated from the pump '
                  'library, so it cannot overstate what the app understands.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const Key('history-coverage-filter'),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter event types',
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          SwitchListTile(
            key: const Key('history-coverage-decoded-only'),
            dense: true,
            title: const Text('Decoded only'),
            value: _decodedOnly,
            onChanged: (v) => setState(() => _decodedOnly = v),
          ),
          const Divider(height: 1),
          Expanded(
            // Paged by the list's own lazy building — 134 rows, only the visible ones
            // are built.
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final t = shown[i];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    t.decoded ? Icons.check_circle : Icons.remove_circle_outline,
                    size: 18,
                    color: t.decoded
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  title: Text(t.name, style: theme.textTheme.bodySmall),
                  subtitle:
                      Text(t.decoded ? 'Decoded' : 'Raw only — not stored as therapy data'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
