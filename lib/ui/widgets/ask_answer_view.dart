/// Renders an ask-your-data answer (issue #80). Split from the screen so the copy and
/// the honesty rules are testable without providers.
library;

import 'package:flutter/material.dart';

import '../../insights/ask_data_service.dart';

class AskAnswerView extends StatelessWidget {
  const AskAnswerView({super.key, required this.answer});

  final AskAnswer answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(answer.text, style: theme.textTheme.bodyMedium),
                if (answer.rejection != null) ...[
                  const SizedBox(height: 10),
                  // Say it plainly. The user is entitled to know the model wrote
                  // something that didn't check out, rather than silently receiving a
                  // different kind of answer than they got last time.
                  Text(
                    "The AI's wording didn't match your data, so it wasn't used — "
                    'these are the measurements themselves.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (answer.facts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Based on', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final f in answer.facts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(f.display, style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
          Text(
            'Every number above is measured from your own readings — nothing here '
            'is estimated or generated.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
        ],
      ],
    );
  }
}
