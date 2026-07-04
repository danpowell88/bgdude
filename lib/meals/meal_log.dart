/// Records that a saved meal was actually eaten, so the outcome loop can — a few hours
/// later — measure how it played out from CGM and refine the meal's learned curve.
///
/// Entries persist in shared_preferences; once their outcome has been computed they are
/// marked learned (kept briefly for history, then pruned).
library;

import 'dart:convert';

import '../data/kv_store.dart';

class MealLogEntry {
  const MealLogEntry({
    required this.id,
    required this.mealId,
    required this.eatenAt,
    required this.carbsGrams,
    required this.preBolusMinutes,
    required this.bolusUnits,
    this.learned = false,
  });

  final String id;
  final String mealId;
  final DateTime eatenAt;
  final double carbsGrams;
  final int preBolusMinutes;
  final double bolusUnits;
  final bool learned;

  MealLogEntry copyWith({bool? learned}) => MealLogEntry(
        id: id,
        mealId: mealId,
        eatenAt: eatenAt,
        carbsGrams: carbsGrams,
        preBolusMinutes: preBolusMinutes,
        bolusUnits: bolusUnits,
        learned: learned ?? this.learned,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'mealId': mealId,
        'eatenAt': eatenAt.toIso8601String(),
        'carbsGrams': carbsGrams,
        'preBolusMinutes': preBolusMinutes,
        'bolusUnits': bolusUnits,
        'learned': learned,
      };

  factory MealLogEntry.fromJson(Map<String, dynamic> j) => MealLogEntry(
        id: j['id'] as String,
        mealId: j['mealId'] as String,
        eatenAt: DateTime.parse(j['eatenAt'] as String),
        carbsGrams: (j['carbsGrams'] as num).toDouble(),
        preBolusMinutes: (j['preBolusMinutes'] as num).toInt(),
        bolusUnits: (j['bolusUnits'] as num).toDouble(),
        learned: j['learned'] as bool? ?? false,
      );
}

class MealLogStore {
  static const _key = 'meal_log_v1';

  static Future<List<MealLogEntry>> load() async {
    final raw = await KvStore.getStringList(_key) ?? const [];
    return [
      for (final r in raw)
        MealLogEntry.fromJson(jsonDecode(r) as Map<String, dynamic>),
    ];
  }

  static Future<void> save(List<MealLogEntry> entries) async {
    // Prune learned entries older than 7 days to bound growth.
    final now = DateTime.now();
    final kept = [
      for (final e in entries)
        if (!e.learned || now.difference(e.eatenAt).inDays < 7) e,
    ];
    await KvStore.setStringList(
        _key, [for (final e in kept) jsonEncode(e.toJson())]);
  }

  static String newId(DateTime at) =>
      at.microsecondsSinceEpoch.toRadixString(36);
}
