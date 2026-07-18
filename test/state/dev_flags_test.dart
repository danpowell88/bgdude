/// The single developer/experiment flag store (issue #96).
library;

import 'package:bgdude/state/dev_flags.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every flag says what it does', () {
    // A flag whose effect nobody remembers is worse than no flag.
    for (final f in devFlags) {
      expect(f.id, isNotEmpty);
      expect(f.label, isNotEmpty);
      expect(f.description, isNotEmpty, reason: f.id);
    }
  });

  test('ids are unique and storage keys are namespaced', () {
    final ids = devFlags.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final f in devFlags) {
      expect(f.storageKey, startsWith('dev_flag_'),
          reason: 'must not collide with AppFlags lifecycle keys');
    }
  });

  test('a flag reads its default before it is ever set', () async {
    final store = await DevFlagStore.load();
    for (final f in devFlags) {
      expect(store.isOn(f), f.defaultValue, reason: f.id);
    }
  });

  test('setting a flag persists it', () async {
    final store = await DevFlagStore.load();
    final flag = devFlags.first;

    await store.set(flag, !flag.defaultValue);

    expect(store.isOn(flag), !flag.defaultValue);
    expect((await DevFlagStore.load()).isOn(flag), !flag.defaultValue,
        reason: 'a fresh store must see the persisted value');
  });

  test('flags are independent of each other', () async {
    // A shared or mistyped key would make two flags move together — the kind of bug
    // that makes a trial look like it did something it did not.
    final store = await DevFlagStore.load();
    expect(devFlags.length, greaterThanOrEqualTo(2));
    final a = devFlags[0];
    final b = devFlags[1];

    await store.set(a, true);

    expect(store.isOn(a), isTrue);
    expect(store.isOn(b), b.defaultValue);
  });

  test('reset returns every flag to its default', () async {
    final store = await DevFlagStore.load();
    for (final f in devFlags) {
      await store.set(f, !f.defaultValue);
    }

    await store.resetAll();

    for (final f in devFlags) {
      expect(store.isOn(f), f.defaultValue, reason: f.id);
    }
  });

  test('all() reports every flag', () async {
    final store = await DevFlagStore.load();
    expect(store.all.keys.toSet(), devFlags.map((f) => f.id).toSet());
  });

  test('an unknown flag id throws rather than reading as off', () {
    // Silently defaulting would make a typo look like a broken feature instead of a
    // missing flag.
    expect(() => devFlagById('no_such_flag'), throwsArgumentError);
    expect(devFlagById(devFlags.first.id).label, devFlags.first.label);
  });

  test('the flag store does not use the app lifecycle keys', () async {
    // dev_mode / pump_paired / onboarding_done gate first-run behaviour; a flag
    // colliding with one of them would be a spectacular way to break onboarding.
    for (final f in devFlags) {
      expect(['dev_mode', 'pump_paired', 'onboarding_done'],
          isNot(contains(f.storageKey)));
    }
  });
}
