/// An always-on tail of pump traffic (issue #92).
///
/// The Protocol Explorer captures messages only while it is open, and only in response
/// to requests you fire from it. This is the other half: a bounded, always-on record of
/// what the pump is actually sending during normal operation, so a decode problem that
/// only happens during a real bolus or an overnight reconnect is still visible
/// afterwards.
///
/// Bounded on purpose. An unbounded buffer of a chatty BLE link is a slow memory leak
/// that only shows up on the long connections that matter most.
library;

import 'probe_event.dart';

/// A fixed-capacity, newest-last record of [ProbeEvent]s.
class MessageRingBuffer {
  MessageRingBuffer({this.capacity = 500})
      : assert(capacity > 0, 'a zero-capacity buffer records nothing');

  /// How many events are kept. Older ones are dropped as new ones arrive.
  final int capacity;

  final List<ProbeEvent> _events = [];

  /// How many events have been dropped to stay within [capacity].
  ///
  /// Surfaced rather than silent: "the oldest 4,000 messages are gone" is the
  /// difference between a tail you can trust and one that quietly lies about when a
  /// problem started.
  int get dropped => _dropped;
  int _dropped = 0;

  int get length => _events.length;
  bool get isEmpty => _events.isEmpty;

  /// Oldest first.
  List<ProbeEvent> get events => List.unmodifiable(_events);

  /// Newest first — the order a live tail is read in.
  List<ProbeEvent> get newestFirst => _events.reversed.toList();

  void add(ProbeEvent event) {
    _events.add(event);
    while (_events.length > capacity) {
      _events.removeAt(0);
      _dropped++;
    }
  }

  void clear() {
    _events.clear();
    _dropped = 0;
  }
}

/// Filters a tail by direction and a free-text needle.
///
/// Matches on name, opcode and cargo, because the three things you actually search for
/// are "that message type", "opcode 107", and "the response containing these bytes".
List<ProbeEvent> filterEvents(
  List<ProbeEvent> events, {
  String query = '',
  String? direction,
}) {
  final needle = query.trim().toLowerCase();
  return [
    for (final e in events)
      if ((direction == null || e.direction == direction) &&
          (needle.isEmpty ||
              e.name.toLowerCase().contains(needle) ||
              (e.opcode?.toString() ?? '').contains(needle) ||
              (e.cargoHex ?? '').toLowerCase().contains(needle)))
        e,
  ];
}

/// One-line summary of an event for the tail.
String describeEvent(ProbeEvent e) {
  final opcode = e.opcode == null ? '' : ' op ${e.opcode}';
  final arrow = e.direction == 'tx' ? '→' : '←';
  return '$arrow ${e.name}$opcode';
}
