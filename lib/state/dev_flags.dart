/// One home for developer and experiment flags (issue #96).
///
/// Before this, anything experimental had nowhere to live except consumer Settings, which
/// is how a settings screen fills up with switches that mean nothing to the person using
/// the app. Flags declared here are read from a single store and rendered in one place —
/// the debug-only Developer menu — so adding one never touches consumer Settings again.
///
/// **Demo mode's Exit control deliberately stays in consumer Settings.** It is not a dev
/// toggle: demo mode is entered during onboarding by ordinary users, on release builds
/// where the Developer menu does not exist, and moving the only way out of it behind a
/// debug-only screen would strand them in simulated data with no route back to their real
/// pump. What moved here is the developer's ability to *enter* demo mode without redoing
/// onboarding, which is a genuinely different thing.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// A developer-facing flag: something being trialled, or a switch that only makes sense
/// to someone working on the app.
class DevFlag {
  const DevFlag({
    required this.id,
    required this.label,
    required this.description,
    this.defaultValue = false,
  });

  /// Stable storage key suffix. Changing it silently resets the flag, so don't.
  final String id;
  final String label;

  /// What turning it on actually does — a flag whose effect nobody remembers is worse
  /// than no flag.
  final String description;
  final bool defaultValue;

  String get storageKey => 'dev_flag_$id';
}

/// Every flag the app knows about. Add here and it appears in the Developer menu.
const List<DevFlag> devFlags = [
  DevFlag(
    id: 'verbose_pump_logging',
    label: 'Verbose pump logging',
    description:
        'Log every pump message exchange to the diagnostics log. Noisy — it will '
        'push older entries out of the ring buffer faster.',
  ),
  DevFlag(
    id: 'show_forecast_internals',
    label: 'Show forecast internals',
    description:
        'Surface the raw model inputs and residuals alongside forecasts, for '
        'checking the predictor against its own working.',
  ),
];

/// Reads and writes [devFlags] through one store.
///
/// Backed by SharedPreferences rather than the encrypted KvStore because these gate
/// behaviour that can run before the database is open — the same reason [AppFlags] lives
/// there.
class DevFlagStore {
  const DevFlagStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<DevFlagStore> load() async =>
      DevFlagStore(await SharedPreferences.getInstance());

  bool isOn(DevFlag flag) =>
      _prefs.getBool(flag.storageKey) ?? flag.defaultValue;

  Future<void> set(DevFlag flag, bool value) =>
      _prefs.setBool(flag.storageKey, value);

  /// Every flag's current state, for the Developer screen and for tests.
  Map<String, bool> get all => {
        for (final f in devFlags) f.id: isOn(f),
      };

  /// Returns flags to their defaults. Debug-only escape hatch for when a trial flag has
  /// left the app in a confusing state.
  Future<void> resetAll() async {
    for (final f in devFlags) {
      await _prefs.remove(f.storageKey);
    }
  }
}

/// Looks up a flag by id. Throws on an unknown id rather than returning a default: a typo
/// that silently reads "off" would make a flag look broken instead of missing.
DevFlag devFlagById(String id) =>
    devFlags.firstWhere((f) => f.id == id, orElse: () {
      throw ArgumentError('unknown dev flag: $id');
    });
