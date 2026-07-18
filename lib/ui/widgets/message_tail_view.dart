/// Renders a pump message tail (issue #92). Split from the screen so the filtering and
/// the dropped-count honesty are testable without the pump stream.
library;

import 'package:flutter/material.dart';

import '../../pump/message_ring_buffer.dart';
import '../../pump/probe_event.dart';

class MessageTailView extends StatelessWidget {
  const MessageTailView({
    super.key,
    required this.events,
    required this.dropped,
    required this.capturing,
  });

  /// Newest first.
  final List<ProbeEvent> events;
  final int dropped;
  final bool capturing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          capturing
              ? 'Nothing yet — messages appear here as the pump sends them.'
              : 'Capture is off, so nothing is being recorded.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    return ListView.builder(
      itemCount: events.length + (dropped > 0 ? 1 : 0),
      itemBuilder: (context, i) {
        // Pinned at the top of the newest-first list, because a tail that silently
        // discarded its own beginning is a tail that lies about when a problem started.
        if (dropped > 0 && i == events.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '$dropped older message${dropped == 1 ? '' : 's'} dropped to stay '
              'within the buffer.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          );
        }
        final e = events[i];
        return ListTile(
          dense: true,
          title: Text(describeEvent(e),
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace')),
          subtitle: e.cargoHex == null
              ? null
              : Text(e.cargoHex!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
        );
      },
    );
  }
}
