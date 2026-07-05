/// A compact, persisted history of pump battery readings — percent + charging state over
/// time — so the drain estimator has a series to extrapolate. Kept in the encrypted
/// key-value store (low volume) and capped. De-duplicated so frequent identical snapshots
/// don't bloat it.
library;

import 'dart:convert';

import '../data/kv_store.dart';

class BatterySample {
  const BatterySample({required this.time, required this.percent, this.charging});

  final DateTime time;
  final int percent;

  /// True/false when known (V2 pumps), null when unknown (V1 / no data).
  final bool? charging;

  Map<String, dynamic> toJson() =>
      {'t': time.toIso8601String(), 'p': percent, 'c': charging};

  factory BatterySample.fromJson(Map<String, dynamic> j) => BatterySample(
        time: DateTime.parse(j['t'] as String),
        percent: (j['p'] as num).toInt(),
        charging: j['c'] as bool?,
      );
}

class BatteryHistoryStore {
  static const _key = 'battery_history_v1';
  static const maxSamples = 500;

  /// Skip a new sample unless something changed or enough time has passed, so a steady
  /// battery at frequent snapshot cadence doesn't fill the log.
  static const _minGap = Duration(minutes: 15);

  static Future<List<BatterySample>> load() async {
    final raw = await KvStore.getString(_key);
    if (raw == null) return const [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return [for (final e in list) BatterySample.fromJson(e)];
  }

  /// Append [sample] if it's new information (percent or charging changed, or it's been
  /// at least [_minGap] since the last), keeping the most recent [maxSamples].
  static Future<void> append(BatterySample sample) async {
    final existing = await load();
    if (existing.isNotEmpty) {
      final last = existing.last;
      final unchanged =
          last.percent == sample.percent && last.charging == sample.charging;
      if (unchanged && sample.time.difference(last.time) < _minGap) return;
    }
    final merged = [...existing, sample];
    final capped = merged.length > maxSamples
        ? merged.sublist(merged.length - maxSamples)
        : merged;
    await KvStore.setString(
        _key, jsonEncode([for (final s in capped) s.toJson()]));
  }
}
