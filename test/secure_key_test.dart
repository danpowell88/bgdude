import 'package:bgdude/data/secure_key.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TASK-8: the DB passphrase lives in Keystore-backed secure storage, migrating any legacy
/// SharedPreferences key so an existing encrypted DB stays readable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('generates a passphrase once and returns the same one thereafter', () async {
    final a = (await SecureKeyStore.open()).getOrCreatePassphrase();
    expect(a, isNotEmpty);
    final b = (await SecureKeyStore.open()).getOrCreatePassphrase();
    expect(b, a); // stable across opens (persisted to secure storage)
  });

  test('migrates a legacy SharedPreferences passphrase and clears it', () async {
    const legacy = 'legacy-passphrase-abc123';
    SharedPreferences.setMockInitialValues({'db_passphrase_v1': legacy});
    final prefs = await SharedPreferences.getInstance();

    final store = await SecureKeyStore.open(legacyPrefs: prefs);
    // The existing key is preserved (so the encrypted DB it protects stays readable).
    expect(store.getOrCreatePassphrase(), legacy);
    // …and removed from the insecure store it was migrated off of.
    expect(prefs.getString('db_passphrase_v1'), isNull);

    // A second open reads it straight from secure storage (no legacy needed).
    final again = await SecureKeyStore.open();
    expect(again.getOrCreatePassphrase(), legacy);
  });

  group('SecureKeyReadFailure (TASK-249)', () {
    test('a null secure read after a key already existed throws instead of '
        'silently generating a new key', () async {
      final first = await SecureKeyStore.open();
      final originalPass = first.getOrCreatePassphrase();

      // Simulate the secure store losing its value (Keystore invalidation etc.)
      // while the plain marker survives — exactly the ambiguous case this guards.
      FlutterSecureStorage.setMockInitialValues({});

      await expectLater(SecureKeyStore.open(), throwsA(isA<SecureKeyReadFailure>()));

      // And confirm it really would have generated a *different* key had it not
      // thrown, so this isn't accidentally testing a no-op.
      FlutterSecureStorage.setMockInitialValues(
          {'db_passphrase_v1': originalPass});
      final recovered = await SecureKeyStore.open();
      expect(recovered.getOrCreatePassphrase(), originalPass);
    });

    test('a genuinely first run (no marker) still generates a key normally', () async {
      final store = await SecureKeyStore.open();
      expect(store.getOrCreatePassphrase(), isNotEmpty);
    });

    test('forgetForReset clears the marker so open() generates fresh instead of '
        'throwing', () async {
      final first = await SecureKeyStore.open();
      FlutterSecureStorage.setMockInitialValues({}); // simulate lost key

      await SecureKeyStore.forgetForReset();

      final afterReset = await SecureKeyStore.open();
      expect(afterReset.getOrCreatePassphrase(), isNotEmpty);
      expect(afterReset.getOrCreatePassphrase(),
          isNot(first.getOrCreatePassphrase()));
    });

    test('the marker is backfilled for a key generated before the marker existed',
        () async {
      // An install from before this fix: a key exists in secure storage but the
      // marker was never set (SharedPreferences starts empty).
      const existingKey = 'pre-existing-key-abc';
      FlutterSecureStorage.setMockInitialValues(
          {'db_passphrase_v1': existingKey});

      final store = await SecureKeyStore.open();
      expect(store.getOrCreatePassphrase(), existingKey);

      // Now simulate a transient read failure on a LATER launch — the marker
      // should have been backfilled by the read above, so this throws rather
      // than silently minting a new key.
      FlutterSecureStorage.setMockInitialValues({});
      await expectLater(SecureKeyStore.open(), throwsA(isA<SecureKeyReadFailure>()));
    });
  });
}
