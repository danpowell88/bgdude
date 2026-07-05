/// Open Food Facts food database — free, no API key, no signup, with an Australian
/// instance and crowdsourced global coverage. Barcode: GET /api/v2/product/{gtin}.json;
/// name search via the search endpoint. Data is ODbL-licensed (attributed in About).
///
/// Completeness varies per product, so every field is treated as optional and callers
/// fall back to manual entry when carbs are missing.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'food_database.dart';
import 'food_item.dart';

class OpenFoodFactsDatabase implements FoodDatabase {
  OpenFoodFactsDatabase({http.Client? client, this.host = 'world.openfoodfacts.org'})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Use 'au.openfoodfacts.org' to bias toward Australian results, or the world host.
  final String host;

  static const _fields =
      'code,product_name,brands,serving_quantity,nutriments';
  static const _headers = {'User-Agent': 'bgdude/0.1 (personal T1D companion)'};

  @override
  String get name => 'Open Food Facts';

  @override
  Future<FoodItem?> lookupBarcode(String gtin) async {
    final uri =
        Uri.https(host, '/api/v2/product/$gtin.json', {'fields': _fields});
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if ((json['status'] as num?)?.toInt() != 1) return null; // 0 = not found
    return parseProduct((json['product'] as Map).cast<String, dynamic>(), gtin);
  }

  @override
  Future<List<FoodItem>> searchByName(String query, {int limit = 20}) async {
    final uri = Uri.https(host, '/cgi/search.pl', {
      'search_terms': query,
      'json': '1',
      'page_size': '$limit',
      'fields': _fields,
    });
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) return const [];
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final products = (json['products'] as List?) ?? const [];
    return [
      for (final p in products)
        parseProduct((p as Map).cast<String, dynamic>(), p['code'] as String?),
    ].whereType<FoodItem>().toList();
  }

  /// Parse an OFF product object into a [FoodItem] (null when it has no usable name).
  static FoodItem? parseProduct(Map<String, dynamic> p, String? gtin) {
    final name = (p['product_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final n = (p['nutriments'] as Map?)?.cast<String, dynamic>() ?? const {};
    double? valOf(String k) => (n[k] as num?)?.toDouble();
    return FoodItem(
      name: name,
      brand: (p['brands'] as String?)?.split(',').first.trim(),
      gtin: gtin,
      carbsPer100g: valOf('carbohydrates_100g'),
      fatPer100g: valOf('fat_100g'),
      proteinPer100g: valOf('proteins_100g'),
      servingSizeG: (p['serving_quantity'] as num?)?.toDouble() ??
          double.tryParse('${p['serving_quantity'] ?? ''}'),
      source: 'Open Food Facts',
    );
  }
}
