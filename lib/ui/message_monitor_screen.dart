/// Live tail of pump traffic (issue #92).
///
/// Sits under Developer beside the Protocol Explorer. The Explorer answers "what does
/// the pump say when I ask it this?"; this answers "what is the pump saying right now,
/// unprompted?" — which is the question when a decode only misbehaves during a real
/// bolus or an overnight reconnect.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pump/message_ring_buffer.dart';
import '../state/providers.dart';
import 'widgets/message_tail_view.dart';

class MessageMonitorScreen extends ConsumerStatefulWidget {
  const MessageMonitorScreen({super.key, this.bufferOverride});

  /// Test seam: the real buffer is filled by a stream from the pump client, which does
  /// not exist on a unit-test host.
  final MessageRingBuffer? bufferOverride;

  @override
  ConsumerState<MessageMonitorScreen> createState() =>
      _MessageMonitorScreenState();
}

class _MessageMonitorScreenState extends ConsumerState<MessageMonitorScreen> {
  String _query = '';
  String? _direction;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // The buffer fills from a stream this screen doesn't own, so poll to redraw
    // rather than rebuilding on every single message — a chatty link would otherwise
    // rebuild the list hundreds of times a second.
    _tick = Timer.periodic(
        const Duration(milliseconds: 500), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buffer =
        widget.bufferOverride ?? ref.watch(messageMonitorProvider).buffer;
    final events = filterEvents(
      buffer.newestFirst,
      query: _query,
      direction: _direction,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message monitor'),
        actions: [
          IconButton(
            key: const Key('message-monitor-clear'),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: () => setState(buffer.clear),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const Key('message-monitor-filter'),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter by name, opcode or bytes',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final (label, value) in const [
                  ('All', null),
                  ('Received', 'rx'),
                  ('Sent', 'tx'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _direction == value,
                      onSelected: (_) => setState(() => _direction = value),
                    ),
                  ),
                const Spacer(),
                Text('${buffer.length}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: MessageTailView(
              events: events,
              dropped: buffer.dropped,
              capturing: true,
            ),
          ),
        ],
      ),
    );
  }
}
