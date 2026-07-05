/// A bundled, offline set of common Australian generic foods (a curated subset in the
/// spirit of the FSANZ Australian Food Composition Database). No barcodes — it's a
/// no-network fallback for name search ("white rice, cooked") and works even when the
/// online lookup is off. Extend by adding rows to assets/food/afcd_generic.json.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'food_database.dart';
import 'food_item.dart';

class OfflineAfcdDatabase implements FoodDatabase {
  OfflineAfcdDatabase(this._items);
  final List<FoodItem> _items;

  static const asset = 'assets/food/afcd_generic.json';

  @override
  String get name => 'Australian foods (offline)';

  /// Load and parse the bundled asset. Falls back to an empty DB if the asset is missing.
  static Future<OfflineAfcdDatabase> load({String path = asset}) async {
    try {
      final raw = await rootBundle.loadString(path);
      return OfflineAfcdDatabase(parse(raw));
    } catch (_) {
      return OfflineAfcdDatabase(const []);
    }
  }

  static List<FoodItem> parse(String jsonStr) {
    final list = (jsonDecode(jsonStr) as List).cast<Map<String, dynamic>>();
    return [
      for (final e in list)
        FoodItem(
          name: e['name'] as String,
          carbsPer100g: (e['carbs'] as num?)?.toDouble(),
          fatPer100g: (e['fat'] as num?)?.toDouble(),
          proteinPer100g: (e['protein'] as num?)?.toDouble(),
          source: 'AFCD (curated)',
        ),
    ];
  }

  @override
  Future<FoodItem?> lookupBarcode(String gtin) async => null; // no barcodes

  @override
  Future<List<FoodItem>> searchByName(String query, {int limit = 20}) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    final words = q.split(RegExp(r'\s+'));
    final scored = <(FoodItem, int)>[];
    for (final f in _items) {
      final name = f.name.toLowerCase();
      final int score;
      if (name == q) {
        score = 3;
      } else if (name.contains(q)) {
        score = 2;
      } else if (words.any((w) => name.contains(w))) {
        score = 1;
      } else {
        continue;
      }
      scored.add((f, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final s in scored.take(limit)) s.$1];
  }
}
