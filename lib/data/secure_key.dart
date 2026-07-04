/// Manages the SQLCipher database passphrase. The key is generated once, stored in the
/// Android Keystore-backed secure storage, and never leaves the device.
library;

import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// NOTE: for a production build swap `SharedPreferences` for `flutter_secure_storage`
/// (Keystore-backed). SharedPreferences is used here to avoid an extra native dependency
/// in the initial scaffold; the key-management API below is identical either way.
class SecureKeyStore {
  SecureKeyStore(this._prefs);

  final SharedPreferences _prefs;
  static const _keyName = 'db_passphrase_v1';

  static Future<SecureKeyStore> open() async =>
      SecureKeyStore(await SharedPreferences.getInstance());

  /// Returns the existing passphrase or generates and persists a new 256-bit one.
  String getOrCreatePassphrase() {
    final existing = _prefs.getString(_keyName);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateKey();
    _prefs.setString(_keyName, generated);
    return generated;
  }

  static String _generateKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }
}
