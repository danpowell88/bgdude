/// TASK-188: every KV restore path must survive corrupt JSON — no uncaught error,
/// defaults active, a loud log entry, the raw value quarantined at `<key>.corrupt`,
/// and (for the clinical settings) a user-visible reset notice.
library;

import 'dart:convert';

import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/insights/alert_thresholds.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/logging/app_log.dart';
import 'package:bgdude/meals/meal_library.dart';
import 'package:bgdude/profile/user_profile.dart';
import 'package:bgdude/state/persisted_state_notifier.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_test/flutter_test.dart';

const _corrupt = '{"truncated": '; // invalid JSON — the classic torn write

Future<void> _settle() async {
  // The hand-rolled notifiers restore fire-and-forget on the in-memory KV map;
  // a few microtask turns are enough for the chain to finish.
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(() {
    KvStore.useMemory();
    appLog.clear();
    CorruptStateNotices.clear();
  });

  Future<void> expectQuarantined(String key) async {
    expect(await KvStore.getString('$key.corrupt'), _corrupt,
        reason: 'raw value must be preserved for diagnosis');
    expect(
        appLog.entries.any((e) =>
            e.level == LogLevel.error &&
            e.tag == 'persistence' &&
            e.message.contains(key)),
        isTrue,
        reason: 'corruption must be loud in the log');
  }

  test('NotificationPrefs: corrupt blob → defaults, logged, quarantined',
      () async {
    await KvStore.setString('notification_prefs_v1', _corrupt);
    final n = NotificationPrefsNotifier();
    await n.restored;
    expect(jsonEncode(n.state.toJson()),
        jsonEncode(NotificationPrefs.defaults().toJson()));
    await expectQuarantined('notification_prefs_v1');
  });

  test('UserProfile: corrupt blob → defaults, logged, quarantined', () async {
    await KvStore.setString('user_profile_v1', _corrupt);
    final n = UserProfileNotifier();
    await n.restored;
    expect(jsonEncode(n.state.toJson()),
        jsonEncode(const UserProfile().toJson()));
    await expectQuarantined('user_profile_v1');
  });

  test('AlertThresholds: corrupt blob → defaults + user-visible reset notice',
      () async {
    await KvStore.setString('alert_thresholds_v1', _corrupt);
    final n = AlertThresholdsNotifier();
    await n.restored;
    expect(n.state.lowMgdl, AlertThresholds.defaultLowMgdl);
    expect(n.state.highMgdl, AlertThresholds.defaultHighMgdl);
    await expectQuarantined('alert_thresholds_v1');
    expect(CorruptStateNotices.notices.value,
        anyElement(contains('alert thresholds')));
  });

  test('TherapySettings: corrupt blob → placeholder + user-visible reset notice',
      () async {
    await KvStore.setString('therapy_settings_v1', _corrupt);
    final n = TherapyNotifier();
    await n.restored;
    expect(jsonEncode(n.state.toJson()),
        jsonEncode(TherapySettings.placeholder().toJson()));
    await expectQuarantined('therapy_settings_v1');
    expect(CorruptStateNotices.notices.value,
        anyElement(contains('therapy settings')));
  });

  test('MedicationMode: corrupt blob → inactive default, logged, quarantined',
      () async {
    await KvStore.setString('medication_mode_v1', _corrupt);
    final n = MedicationModeNotifier();
    await _settle();
    expect(n.state.active, isFalse);
    await expectQuarantined('medication_mode_v1');
  });

  test('WeatherSettings: corrupt blob → defaults, logged, quarantined', () async {
    await KvStore.setString('weather_settings_v1', _corrupt);
    final n = WeatherSettingsNotifier();
    await n.restored;
    expect(n.state.enabled, isFalse);
    expect(n.state.city, isEmpty);
    await expectQuarantined('weather_settings_v1');
  });

  test('NightscoutConfig: corrupt blob → defaults, logged, quarantined',
      () async {
    await KvStore.setString('nightscout_config_v1', _corrupt);
    final n = NightscoutConfigNotifier();
    await n.restored;
    expect(n.state.baseUrl, isEmpty);
    expect(n.state.enabled, isFalse);
    await expectQuarantined('nightscout_config_v1');
  });

  test('IllnessMode: corrupt blob → inactive, logged, quarantined', () async {
    await KvStore.setString('illness_mode_v1', _corrupt);
    final n = IllnessModeNotifier();
    await _settle();
    expect(n.state.active, isFalse);
    await expectQuarantined('illness_mode_v1');
  });

  test('MealLibrary: one corrupt item is quarantined, valid meals survive',
      () async {
    final valid = jsonEncode(const SavedMeal(
      id: 'm1',
      name: 'Toast',
      emoji: '🍞',
      carbsGrams: 30,
    ).toJson());
    await KvStore.setStringList('meal_library_v1', [valid, _corrupt]);
    final n = MealLibraryNotifier();
    await _settle();
    expect(n.state.meals, hasLength(1));
    expect(n.state.meals.single.name, 'Toast');
    await expectQuarantined('meal_library_v1');
  });

  test('a WRONG-SHAPE blob (valid JSON, wrong type) is also caught', () async {
    await KvStore.setString('user_profile_v1', '[1,2,3]');
    final n = UserProfileNotifier();
    await n.restored;
    expect(jsonEncode(n.state.toJson()),
        jsonEncode(const UserProfile().toJson()));
    expect(await KvStore.getString('user_profile_v1.corrupt'), '[1,2,3]');
  });
}
