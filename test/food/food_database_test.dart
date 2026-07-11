import 'package:bgdude/food/food_database.dart';
import 'package:bgdude/food/food_item.dart';
import 'package:bgdude/food/offline_afcd.dart';
import 'package:bgdude/food/open_food_facts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('FoodItem', () {
    const item = FoodItem(
        name: 'Rice', source: 'x', carbsPer100g: 28, fatPer100g: 0.3, proteinPer100g: 2.7);
    test('scales macros to a portion', () {
      expect(item.carbsForGrams(150), closeTo(42, 1e-9));
      expect(item.proteinForGrams(200), closeTo(5.4, 1e-9));
    });
    test('displayName includes the brand', () {
      expect(const FoodItem(name: 'Tim Tam', brand: "Arnott's", source: 'x').displayName,
          "Tim Tam · Arnott's");
    });
  });

  group('OpenFoodFactsDatabase', () {
    OpenFoodFactsDatabase withResponse(String body, [int status = 200]) =>
        OpenFoodFactsDatabase(
            client: MockClient((_) async => http.Response(body, status)));

    test('parses a found product with nutriments', () async {
      final db = withResponse('''
        {"status":1,"product":{"product_name":"Tim Tam","brands":"Arnott's",
          "serving_quantity":18,
          "nutriments":{"carbohydrates_100g":64.0,"fat_100g":26.0,"proteins_100g":5.0}}}''');
      final item = await db.lookupBarcode('9310072030000');
      expect(item, isNotNull);
      expect(item!.name, 'Tim Tam');
      expect(item.brand, "Arnott's");
      expect(item.gtin, '9310072030000');
      expect(item.carbsPer100g, 64.0);
      expect(item.fatPer100g, 26.0);
      expect(item.servingSizeG, 18);
      expect(item.hasCarbs, isTrue);
    });

    test('returns null when the product is not found (status 0)', () async {
      final db = withResponse('{"status":0,"product":{}}');
      expect(await db.lookupBarcode('0000000000000'), isNull);
    });

    test('returns null on a non-200 response', () async {
      final db = withResponse('server error', 500);
      expect(await db.lookupBarcode('123'), isNull);
    });

    test('parseProduct rejects a nameless product', () {
      expect(OpenFoodFactsDatabase.parseProduct({'nutriments': <String, dynamic>{}}, '123'),
          isNull);
    });

    test('name search maps the products array', () async {
      final db = withResponse('''
        {"products":[
          {"code":"111","product_name":"Weet-Bix","nutriments":{"carbohydrates_100g":67}},
          {"code":"222","nutriments":{"carbohydrates_100g":10}}
        ]}''');
      final results = await db.searchByName('weet');
      expect(results, hasLength(1)); // the nameless one is dropped
      expect(results.first.name, 'Weet-Bix');
    });
  });

  group('OfflineAfcdDatabase', () {
    final db = OfflineAfcdDatabase(OfflineAfcdDatabase.parse('''
      [{"name":"White rice, cooked","carbs":28,"fat":0.3,"protein":2.7},
       {"name":"Brown rice, cooked","carbs":23,"fat":0.9,"protein":2.6},
       {"name":"Banana","carbs":21,"fat":0.3,"protein":1.1}]'''));

    test('has no barcodes', () async {
      expect(await db.lookupBarcode('123'), isNull);
    });

    test('name search ranks exact/substring/word matches', () async {
      final rice = await db.searchByName('rice');
      expect(rice, hasLength(2));
      expect(rice.every((f) => f.name.toLowerCase().contains('rice')), isTrue);

      final exact = await db.searchByName('banana');
      expect(exact.first.name, 'Banana');

      expect(await db.searchByName('pizza'), isEmpty);
    });
  });

  group('CompositeFoodDatabase', () {
    test('barcode: first provider that has it wins; errors are skipped', () async {
      final composite = CompositeFoodDatabase([
        _ThrowingDb(),
        _FixedDb(const FoodItem(name: 'Found', source: 'b', carbsPer100g: 10)),
        _FixedDb(const FoodItem(name: 'Later', source: 'c', carbsPer100g: 20)),
      ]);
      final item = await composite.lookupBarcode('123');
      expect(item!.name, 'Found');
    });

    test('barcode: null when no provider has it', () async {
      final composite = CompositeFoodDatabase([_ThrowingDb(), _EmptyDb()]);
      expect(await composite.lookupBarcode('123'), isNull);
    });

    test('search merges across providers', () async {
      final composite = CompositeFoodDatabase([
        _SearchDb([const FoodItem(name: 'A', source: 'off')]),
        _SearchDb([const FoodItem(name: 'B', source: 'afcd')]),
      ]);
      final results = await composite.searchByName('x');
      expect(results.map((f) => f.name), containsAll(['A', 'B']));
    });
  });
}

class _ThrowingDb implements FoodDatabase {
  @override
  String get name => 'throws';
  @override
  Future<FoodItem?> lookupBarcode(String gtin) async => throw Exception('down');
  @override
  Future<List<FoodItem>> searchByName(String q, {int limit = 20}) async =>
      throw Exception('down');
}

class _EmptyDb implements FoodDatabase {
  @override
  String get name => 'empty';
  @override
  Future<FoodItem?> lookupBarcode(String gtin) async => null;
  @override
  Future<List<FoodItem>> searchByName(String q, {int limit = 20}) async => const [];
}

class _FixedDb implements FoodDatabase {
  _FixedDb(this.item);
  final FoodItem item;
  @override
  String get name => 'fixed';
  @override
  Future<FoodItem?> lookupBarcode(String gtin) async => item;
  @override
  Future<List<FoodItem>> searchByName(String q, {int limit = 20}) async => [item];
}

class _SearchDb implements FoodDatabase {
  _SearchDb(this.items);
  final List<FoodItem> items;
  @override
  String get name => 'search';
  @override
  Future<FoodItem?> lookupBarcode(String gtin) async => null;
  @override
  Future<List<FoodItem>> searchByName(String q, {int limit = 20}) async => items;
}
