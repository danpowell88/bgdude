/// The developer/experiment flag switches (issue #96). Extracted so the panel's copy and
/// behaviour are testable without the Developer screen's provider graph.
library;

import 'package:flutter/material.dart';

import '../../state/dev_flags.dart';

class DevFlagsPanel extends StatelessWidget {
  const DevFlagsPanel({
    super.key,
    required this.values,
    required this.onChanged,
    this.onReset,
  });

  /// Flag id → current value.
  final Map<String, bool> values;
  final void Function(DevFlag flag, bool value) onChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Experiment flags',
                    style: theme.textTheme.titleSmall),
              ),
              if (onReset != null)
                TextButton(
                  key: const Key('dev-flags-reset'),
                  onPressed: onReset,
                  child: const Text('Reset'),
                ),
            ],
          ),
        ),
        for (final flag in devFlags)
          SwitchListTile(
            key: Key('dev-flag-${flag.id}'),
            title: Text(flag.label),
            // Always show what the flag does: one whose effect nobody remembers is
            // worse than no flag at all.
            subtitle: Text(flag.description,
                style: theme.textTheme.bodySmall),
            value: values[flag.id] ?? flag.defaultValue,
            onChanged: (v) => onChanged(flag, v),
          ),
      ],
    );
  }
}
