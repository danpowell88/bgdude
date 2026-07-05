/// A compact, persisted timeline of notable pump events decoded from the History Log —
/// alarms, alerts, and cartridge changes — for the Pump screen. Kept in the encrypted
/// key-value store (not a table) and capped, since these are low-volume and only need to
/// be shown recently-first.
library;

import 'dart:convert';

import '../data/kv_store.dart';

enum PumpEventKind { alarm, alert, cartridgeChange, cannulaChange }

extension PumpEventKindX on PumpEventKind {
  String get label => switch (this) {
        PumpEventKind.alarm => 'Alarm',
        PumpEventKind.alert => 'Alert',
        PumpEventKind.cartridgeChange => 'Cartridge change',
        PumpEventKind.cannulaChange => 'Site change',
      };
}

class PumpEvent {
  const PumpEvent({required this.time, required this.kind, required this.detail});

  final DateTime time;
  final PumpEventKind kind;

  /// Human-readable specifics (e.g. the alarm/alert name).
  final String detail;

  Map<String, dynamic> toJson() => {
        't': time.toIso8601String(),
        'k': kind.name,
        'd': detail,
      };

  factory PumpEvent.fromJson(Map<String, dynamic> j) => PumpEvent(
        time: DateTime.parse(j['t'] as String),
        kind: PumpEventKind.values.byName(j['k'] as String),
        detail: (j['d'] as String?) ?? '',
      );

  /// Identity for de-duplication across re-syncs.
  String get _key => '${time.millisecondsSinceEpoch}:${kind.name}:$detail';
}

class PumpEventLog {
  static const _storeKey = 'pump_events_v1';
  static const maxEvents = 100;

  static Future<List<PumpEvent>> load() async {
    final raw = await KvStore.getString(_storeKey);
    if (raw == null) return const [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return [for (final e in list) PumpEvent.fromJson(e)];
  }

  /// Merge [events] into the stored log, de-duplicating and keeping only the most
  /// recent [maxEvents], newest first.
  static Future<void> append(Iterable<PumpEvent> events) async {
    if (events.isEmpty) return;
    final existing = await load();
    final byKey = <String, PumpEvent>{for (final e in existing) e._key: e};
    for (final e in events) {
      byKey[e._key] = e;
    }
    final merged = byKey.values.toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    final capped = merged.take(maxEvents).toList();
    await KvStore.setString(
        _storeKey, jsonEncode([for (final e in capped) e.toJson()]));
  }
}
