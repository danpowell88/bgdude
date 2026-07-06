/// Typed accessors for the three app-lifecycle flags that live in [SharedPreferences]
/// (outside the encrypted KvStore because they gate first-run before the DB is open).
///
/// The raw string keys are defined here exactly once (TASK-106) so the six call sites can
/// no longer typo or desync them. When the KvStore DI seam lands (TASK-36), this wrapper is
/// the single place to swap the backing store for the [KeyValueStore] interface.
library;

import 'package:shared_preferences/shared_preferences.dart';

class AppFlags {
  const AppFlags(this._prefs);

  final SharedPreferences _prefs;

  static const String kDevMode = 'dev_mode';
  static const String kPumpPaired = 'pump_paired';
  static const String kOnboardingDone = 'onboarding_done';

  static Future<AppFlags> load() async =>
      AppFlags(await SharedPreferences.getInstance());

  /// Demo/dev mode: running against the simulated pump + CGM.
  bool get devMode => _prefs.getBool(kDevMode) ?? false;
  Future<void> setDevMode(bool value) => _prefs.setBool(kDevMode, value);

  /// A real pump has been paired at least once (returning user).
  bool get pumpPaired => _prefs.getBool(kPumpPaired) ?? false;
  Future<void> setPumpPaired(bool value) => _prefs.setBool(kPumpPaired, value);

  /// Onboarding has been completed.
  bool get onboardingDone => _prefs.getBool(kOnboardingDone) ?? false;
  Future<void> setOnboardingDone(bool value) =>
      _prefs.setBool(kOnboardingDone, value);
}
