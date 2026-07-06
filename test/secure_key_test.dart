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
}
