/// Manages the SQLCipher database passphrase. The key is generated once and stored in
/// Keystore-backed secure storage (`flutter_secure_storage`, which on Android wraps the
/// value with a key held in the hardware Keystore), so reading the app's files alone does
/// not yield the DB key (TASK-8).
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown by [SecureKeyStore.open] when secure storage returns no passphrase but a
/// plain marker records that one was already generated/migrated previously — i.e.
/// this looks like a transient Keystore read failure (common after OS updates,
/// device restores, or biometric changes), not a genuine first run. Silently
/// generating a fresh key in that case would orphan the still-intact encrypted
/// database under the old, now-unreachable key (TASK-249) — callers should surface
/// this as a distinct, retry-able failure rather than funnelling straight into "no
/// data can be salvaged, reset."
class SecureKeyReadFailure implements Exception {
  const SecureKeyReadFailure();

  @override
  String toString() =>
      'SecureKeyReadFailure: secure storage returned no passphrase, but one was '
      'already generated previously — this looks like a transient read failure, '
      'not a first run.';
}

class SecureKeyStore {
  SecureKeyStore._(this._passphrase);

  final String _passphrase;
  static const _keyName = 'db_passphrase_v1';

  /// Plain (non-secure) marker: true once a passphrase has ever been generated or
  /// migrated. A read against this plain store isn't subject to the same
  /// Keystore-specific failure mode as [FlutterSecureStorage.read] (TASK-249), so it
  /// can reliably distinguish "never set" from "secure storage failed to read an
  /// existing key".
  static const _generatedMarkerKey = 'db_passphrase_v1_generated';

  /// Android options that back the store with the hardware Keystore (EncryptedSharedPrefs).
  static const _androidOptions =
      AndroidOptions(encryptedSharedPreferences: true);

  /// Resolve the passphrase: read it from secure storage, migrating a key written by the
  /// old SharedPreferences implementation (so an existing encrypted DB stays readable), or
  /// generate a fresh one. The write is **awaited before this returns**, so callers that
  /// `await open()` before opening the DB never race an unpersisted key (AC#3).
  ///
  /// Throws [SecureKeyReadFailure] instead of generating a new key when the secure
  /// read comes back empty but [_generatedMarkerKey] says a key already exists
  /// (TASK-249) — see that class's doc comment for why.
  static Future<SecureKeyStore> open({
    FlutterSecureStorage? storage,
    SharedPreferences? legacyPrefs,
  }) async {
    final secure =
        storage ?? const FlutterSecureStorage(aOptions: _androidOptions);
    final prefs = legacyPrefs ?? await SharedPreferences.getInstance();

    var pass = await secure.read(key: _keyName);
    if (pass != null && pass.isNotEmpty) {
      // Backfill the marker for installs that generated their key before this
      // marker existed, so a future transient read failure is recognised correctly.
      if (prefs.getBool(_generatedMarkerKey) != true) {
        await prefs.setBool(_generatedMarkerKey, true);
      }
      return SecureKeyStore._(pass);
    }

    // Migrate off SharedPreferences if a legacy key exists — otherwise the encrypted DB it
    // protects would become unreadable.
    final legacy = prefs.getString(_keyName);
    if (legacy != null && legacy.isNotEmpty) {
      pass = legacy;
      await secure.write(key: _keyName, value: pass);
      await prefs.remove(_keyName);
      await prefs.setBool(_generatedMarkerKey, true);
      return SecureKeyStore._(pass);
    }

    if (prefs.getBool(_generatedMarkerKey) == true) {
      throw const SecureKeyReadFailure();
    }

    pass = _generateKey();
    await secure.write(key: _keyName, value: pass);
    await prefs.setBool(_generatedMarkerKey, true);
    return SecureKeyStore._(pass);
  }

  /// The resolved passphrase (already loaded/created by [open]).
  String getOrCreatePassphrase() => _passphrase;

  /// Clears the persisted-key marker so a subsequent [open] treats this as a fresh
  /// install and generates a new passphrase, instead of throwing
  /// [SecureKeyReadFailure]. Only for the explicit, user-confirmed "reset storage"
  /// recovery action (TASK-249) — never called on an ordinary open path.
  static Future<void> forgetForReset({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(_generatedMarkerKey);
  }

  static String _generateKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }
}
