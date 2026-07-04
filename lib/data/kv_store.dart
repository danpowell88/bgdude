/// A tiny typed facade over the encrypted key-value table (`AppKv`), so app state that
/// used to sit in SharedPreferences (therapy profile, illness/device state, meals,
/// goals, the residual model blob) is now AES-256 encrypted at rest with the rest of the
/// health data.
///
/// Initialised once in `main()` with the opened database. When uninitialised (tests, or
/// a DB that failed to open) it falls back to an in-process map so callers still work.
library;

import 'dart:convert';

import 'database.dart';

class KvStore {
  KvStore._();

  static AppDatabase? _db;
  static final Map<String, String> _mem = {};

  static void init(AppDatabase db) => _db = db;

  /// Test/reset hook.
  static void useMemory() {
    _db = null;
    _mem.clear();
  }

  static Future<String?> getString(String key) async {
    final db = _db;
    if (db == null) return _mem[key];
    return db.readKv(key);
  }

  static Future<void> setString(String key, String value) async {
    final db = _db;
    if (db == null) {
      _mem[key] = value;
      return;
    }
    await db.writeKv(key, value);
  }

  static Future<List<String>?> getStringList(String key) async {
    final s = await getString(key);
    if (s == null) return null;
    return (jsonDecode(s) as List).cast<String>();
  }

  static Future<void> setStringList(String key, List<String> value) =>
      setString(key, jsonEncode(value));

  static Future<double?> getDouble(String key) async {
    final s = await getString(key);
    return s == null ? null : double.tryParse(s);
  }

  static Future<void> setDouble(String key, double value) =>
      setString(key, '$value');

  static Future<bool?> getBool(String key) async {
    final s = await getString(key);
    return s == null ? null : s == 'true';
  }

  static Future<void> setBool(String key, bool value) =>
      setString(key, value ? 'true' : 'false');
}
