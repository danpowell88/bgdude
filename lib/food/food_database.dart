/// A pluggable food-lookup source. The app defaults to Open Food Facts (free, no key) for
/// barcodes plus a bundled offline Australian generic-food set, but any provider that
/// implements this interface can be added or swapped.
library;

import 'food_item.dart';

abstract interface class FoodDatabase {
  String get name;

  /// Look up a product by GTIN/EAN/UPC barcode. Returns null when not found or the
  /// provider has no barcode index.
  Future<FoodItem?> lookupBarcode(String gtin);

  /// Search by name. Returns [] when unsupported or nothing matches.
  Future<List<FoodItem>> searchByName(String query, {int limit = 20});
}

/// Tries providers in order for barcodes (first hit wins) and merges name-search results.
/// Any provider that throws (e.g. network down) is skipped, so an online failure never
/// takes out the offline fallback.
class CompositeFoodDatabase implements FoodDatabase {
  CompositeFoodDatabase(this.providers);
  final List<FoodDatabase> providers;

  @override
  String get name => 'All sources';

  @override
  Future<FoodItem?> lookupBarcode(String gtin) async {
    for (final p in providers) {
      try {
        final r = await p.lookupBarcode(gtin);
        if (r != null) return r;
      } catch (_) {/* skip this provider */}
    }
    return null;
  }

  @override
  Future<List<FoodItem>> searchByName(String query, {int limit = 20}) async {
    final out = <FoodItem>[];
    for (final p in providers) {
      if (out.length >= limit) break;
      try {
        out.addAll(await p.searchByName(query, limit: limit));
      } catch (_) {/* skip this provider */}
    }
    return out.take(limit).toList();
  }
}
