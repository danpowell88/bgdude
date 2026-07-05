/// A small persisted log of daily ambient temperature, so the correlation report can
/// relate weather to daily glucose outcomes. Keyed by calendar day; capped.
library;

import 'dart:convert';

import '../data/kv_store.dart';

class WeatherHistoryStore {
  static const _key = 'weather_history_v1';
  static const _maxDays = 120;

  static String _dayKey(DateTime t) => '${t.year}-${t.month}-${t.day}';

  /// Day-key → temperature (°C). Used by the correlation report.
  static Future<Map<String, double>> loadDaily() async {
    final raw = await KvStore.getString(_key);
    if (raw == null) return const {};
    final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
    return {for (final e in map.entries) e.key: (e.value as num).toDouble()};
  }

  /// Record the temperature for [at]'s day (last write wins), keeping the most recent
  /// [_maxDays] days.
  static Future<void> record(DateTime at, double tempC) async {
    final map = {...await loadDaily(), _dayKey(at): tempC};
    if (map.length > _maxDays) {
      final keys = map.keys.toList()..sort();
      for (final k in keys.take(map.length - _maxDays)) {
        map.remove(k);
      }
    }
    await KvStore.setString(_key, jsonEncode(map));
  }
}
