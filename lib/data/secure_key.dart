/// Manages the SQLCipher database passphrase. The key is generated once and stored in
/// Keystore-backed secure storage (`flutter_secure_storage`, which on Android wraps the
/// value with a key held in the hardware Keystore), so reading the app's files alone does
/// not yield the DB key (TASK-8).
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureKeyStore {
  SecureKeyStore._(this._passphrase);

  final String _passphrase;
  static const _keyName = 'db_passphrase_v1';

  /// Android options that back the store with the hardware Keystore (EncryptedSharedPrefs).
  static const _androidOptions =
      AndroidOptions(encryptedSharedPreferences: true);

  /// Resolve the passphrase: read it from secure storage, migrating a key written by the
  /// old SharedPreferences implementation (so an existing encrypted DB stays readable), or
  /// generate a fresh one. The write is **awaited before this returns**, so callers that
  /// `await open()` before opening the DB never race an unpersisted key (AC#3).
  static Future<SecureKeyStore> open({
    FlutterSecureStorage? storage,
    SharedPreferences? legacyPrefs,
  }) async {
    final secure =
        storage ?? const FlutterSecureStorage(aOptions: _androidOptions);

    var pass = await secure.read(key: _keyName);
    if (pass != null && pass.isNotEmpty) return SecureKeyStore._(pass);

    // Migrate off SharedPreferences if a legacy key exists — otherwise the encrypted DB it
    // protects would become unreadable.
    final prefs = legacyPrefs ?? await SharedPreferences.getInstance();
    final legacy = prefs.getString(_keyName);
    if (legacy != null && legacy.isNotEmpty) {
      pass = legacy;
      await secure.write(key: _keyName, value: pass);
      await prefs.remove(_keyName);
    } else {
      pass = _generateKey();
      await secure.write(key: _keyName, value: pass);
    }
    return SecureKeyStore._(pass);
  }

  /// The resolved passphrase (already loaded/created by [open]).
  String getOrCreatePassphrase() => _passphrase;

  static String _generateKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }
}
