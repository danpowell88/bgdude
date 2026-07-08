/// TASK-188: every KV restore path must survive corrupt JSON — no uncaught error,
/// defaults active, a loud log entry, the raw value quarantined at `<key>.corrupt`,
/// and (for the clinical settings) a user-visible reset notice.
library;

import 'dart:convert';
import 'dart:io';

import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/data/database.dart';
import 'package:bgdude/data/history_repository.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/feedback/pending_confirmation.dart';
import 'package:bgdude/insights/alert_thresholds.dart';
import 'package:bgdude/insights/medication_mode.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/integrations/glucose_meter.dart';
import 'package:bgdude/integrations/glucose_meter_controller.dart';
import 'package:bgdude/integrations/glucose_meter_service.dart';
import 'package:bgdude/integrations/glucose_meter_transport.dart';
import 'package:bgdude/logging/app_log.dart';
import 'package:bgdude/logging/device_changes.dart';
import 'package:bgdude/meals/meal_library.dart';
import 'package:bgdude/profile/user_profile.dart';
import 'package:bgdude/pump/battery_history.dart';
import 'package:bgdude/pump/pump_events.dart';
import 'package:bgdude/state/persisted_state_notifier.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/weather/weather_history.dart';
import 'package:drift/native.dart';
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

  // TASK-206: the same unguarded-restore pattern outside providers.dart, across 6
  // stores. These log loudly (appLog) rather than fully quarantine — a proportionate
  // response for secondary caches/history logs, not clinical settings.
  group('TASK-206 stores outside providers.dart', () {
    bool loggedError(String tag, String messageContains) => appLog.entries.any((e) =>
        e.level == LogLevel.error &&
        e.tag == tag &&
        e.message.contains(messageContains));

    test('PumpEventLog: a totally corrupt blob → empty list, logged', () async {
      await KvStore.setString('pump_events_v1', _corrupt);
      expect(await PumpEventLog.load(), isEmpty);
      expect(loggedError('persistence', 'pump event log'), isTrue);
    });

    test(
        'PumpEventLog: one entry with an unknown PumpEventKind is skipped, valid '
        'entries survive', () async {
      final good = PumpEvent(
              time: DateTime(2026, 7, 1), kind: PumpEventKind.alarm, detail: 'Low insulin')
          .toJson();
      final bad = {'t': DateTime(2026, 7, 1).toIso8601String(), 'k': 'noLongerExists', 'd': 'x'};
      await KvStore.setString('pump_events_v1', jsonEncode([good, bad]));
      final events = await PumpEventLog.load();
      expect(events, hasLength(1));
      expect(events.single.detail, 'Low insulin');
      expect(loggedError('persistence', 'corrupt pump event entry'), isTrue);
    });

    test('BatteryHistoryStore: a totally corrupt blob → empty list, logged',
        () async {
      await KvStore.setString('battery_history_v1', _corrupt);
      expect(await BatteryHistoryStore.load(), isEmpty);
      expect(loggedError('persistence', 'battery history'), isTrue);
    });

    test(
        'BatteryHistoryStore: one malformed entry is skipped, valid entries '
        'survive', () async {
      final good =
          BatterySample(time: DateTime(2026, 7, 1), percent: 80).toJson();
      const bad = {'t': 'not-a-date', 'p': 50};
      await KvStore.setString(
          'battery_history_v1', jsonEncode([good, bad]));
      final samples = await BatteryHistoryStore.load();
      expect(samples, hasLength(1));
      expect(samples.single.percent, 80);
      expect(loggedError('persistence', 'corrupt battery sample'), isTrue);
    });

    test(
        'ConfirmationDecisionStore: a totally corrupt blob → empty map, logged',
        () async {
      await KvStore.setString('confirmation_decisions_v1', _corrupt);
      expect(await ConfirmationDecisionStore.load(), isEmpty);
      expect(loggedError('persistence', 'confirmation decisions'), isTrue);
    });

    test(
        'ConfirmationDecisionStore: one malformed entry is skipped, valid '
        'entries survive', () async {
      await KvStore.setString(
          'confirmation_decisions_v1',
          jsonEncode({
            'good:1': {'d': 'confirmed', 't': DateTime(2026, 7, 1).toIso8601String()},
            'bad:2': 'not-a-map',
          }));
      final decisions = await ConfirmationDecisionStore.load();
      expect(decisions, {'good:1': ConfirmationDecision.confirmed});
      expect(loggedError('persistence', 'corrupt confirmation-decision entry'),
          isTrue);
    });

    test('WeatherHistoryStore: a totally corrupt blob → empty map, logged',
        () async {
      await KvStore.setString('weather_history_v1', _corrupt);
      expect(await WeatherHistoryStore.loadDaily(), isEmpty);
      expect(loggedError('persistence', 'weather history'), isTrue);
    });

    test(
        'WeatherHistoryStore: one malformed value is skipped, valid days '
        'survive', () async {
      await KvStore.setString('weather_history_v1',
          jsonEncode({'2026-7-1': 22.5, '2026-7-2': 'not-a-number'}));
      final daily = await WeatherHistoryStore.loadDaily();
      expect(daily, {'2026-7-1': 22.5});
      expect(loggedError('persistence', 'corrupt weather-history entry'), isTrue);
    });

    test('DeviceChangeStore: a totally corrupt blob → default state, logged',
        () async {
      await KvStore.setString('device_changes_v1', _corrupt);
      final state = await DeviceChangeStore.load();
      expect(state.changes, isEmpty);
      expect(loggedError('persistence', 'device-change store'), isTrue);
    });

    test(
        'DeviceChangeStore: one entry with an unknown DeviceKind is skipped, '
        'valid entries survive', () async {
      final good =
          DeviceChange(kind: DeviceKind.sensor, changedAt: DateTime(2026, 7, 1))
              .toJson();
      final bad = {'kind': 'noLongerExists', 'changedAt': DateTime(2026, 7, 2).toIso8601String()};
      await KvStore.setString(
          'device_changes_v1',
          jsonEncode({
            'changes': [good, bad]
          }));
      final state = await DeviceChangeStore.load();
      expect(state.changes, hasLength(1));
      expect(state.changes.single.kind, DeviceKind.sensor);
      expect(loggedError('persistence', 'corrupt device-change entry'), isTrue);
    });

    test(
        'GlucoseMeterController: a corrupt paired-device blob does not crash the '
        'constructor and leaves the controller unpaired', () async {
      await KvStore.setString('glucose_meter_device_v1', _corrupt);
      final controller = GlucoseMeterController(
        service: GlucoseMeterService(
          transport: _NoopTransport(),
          repository: InMemoryHistoryRepository(),
        ),
        transport: _NoopTransport(),
      );
      await _settle();
      expect(controller.state.isPaired, isFalse);
      expect(
          loggedError('persistence', 'corrupt glucose-meter pairing state'),
          isTrue);
    });
  });

  // TASK-260: a WRITE failure (not corrupt-on-read, the rest of this file's focus)
  // must not leave dosing math and the UI (or, for meal library, in-session state
  // and disk) disagreeing about what actually happened. Points KvStore at a database
  // file whose name is too long to open (fails identically on Windows/NTFS and
  // Linux/ext4's ~255-byte filename limit) so setString/setStringList reliably
  // throw, standing in for any real write failure. A CLOSED in-memory database was
  // tried first and does not work -- drift/sqlite3 accepts writes against it
  // silently rather than throwing, so it wouldn't actually exercise this path.
  group('TASK-260: persist-failure reconciliation', () {
    Future<void> poisonKvStore() async {
      final unopenable = File('${Directory.systemTemp.path}/${'x' * 300}.db');
      KvStore.init(AppDatabase(NativeDatabase(unopenable)));
    }

    test(
        'IllnessMode: a failed activate() write reverts dosing math to match '
        'the still-off UI state', () async {
      final n = IllnessModeNotifier();
      await _settle();
      await poisonKvStore();

      n.activate(boost: 1.8);
      await _settle();

      expect(n.state.active, isFalse,
          reason: 'the write failed, so the UI-visible state never changed');
      expect(n.overlay(SensitivityContext.neutral), SensitivityContext.neutral,
          reason: 'dosing math must not apply a boost that was never saved '
              'and that the UI still shows as off');
    });

    test(
        'IllnessMode: a failed deactivate() write reverts dosing math to '
        'match the still-on UI state', () async {
      final n = IllnessModeNotifier();
      await _settle();
      n.activate(boost: 1.5);
      await _settle();
      expect(n.state.active, isTrue); // precondition: really on before poisoning

      await poisonKvStore();
      n.deactivate();
      await _settle();

      expect(n.state.active, isTrue,
          reason: 'the write failed, so the UI-visible state is still on');
      expect(n.overlay(SensitivityContext.neutral) == SensitivityContext.neutral,
          isFalse,
          reason: 'dosing math must still apply the boost -- deactivation was '
              'never actually saved, and the UI still shows illness mode on');
    });

    test(
        'MedicationMode: a failed start() write reverts state so it does not '
        'keep claiming to be active for the rest of the session', () async {
      final n = MedicationModeNotifier();
      await _settle();
      await poisonKvStore();

      await n.start(MedicationIntensity.high);

      expect(n.state.active, isFalse,
          reason: 'the write failed -- state must revert, not keep claiming '
              'a change that was never saved (it would otherwise silently '
              'diverge from disk for the rest of the session)');
    });

    test(
        'MealLibrary: a failed add() write reverts state so the meal does '
        'not appear to exist for the rest of the session', () async {
      final n = MealLibraryNotifier();
      await _settle();
      await poisonKvStore();

      n.add(const SavedMeal(
        id: 'm1',
        name: 'Toast',
        emoji: '🍞',
        carbsGrams: 30,
      ));
      await _settle();

      expect(n.state.meals, isEmpty,
          reason: 'the write failed -- the meal must not appear to exist '
              'in-session when it was never actually saved');
    });
  });

  // TASK-258: lastDeactivationAnnotation was built by deactivate()/
  // deactivateIfExpired() but nothing ever read/saved it into the history
  // repository -- the retraining pipeline's sick-day tagging silently never
  // happened. The auto-expiry path is covered end-to-end in
  // restart_recovery_test.dart; this covers the manual deactivate() path plus
  // the persist-failure interaction TASK-260's reconciliation raised.
  group('TASK-258: illness deactivation annotation persistence', () {
    test('a manual deactivate() saves the annotation to the history repository',
        () async {
      final repo = InMemoryHistoryRepository();
      final n = IllnessModeNotifier(historyRepository: repo);
      await _settle();
      n.activate(boost: 1.5, notes: 'flu');
      await _settle();

      n.deactivate();
      await _settle();

      final saved = await repo.annotations(DateTime(2020), DateTime(2030));
      expect(saved, isNotEmpty,
          reason: 'the deactivation annotation must reach the history '
              'repository, not just sit in the transient field');
      expect(saved.single.kind, AnnotationKind.illness);
      expect(n.lastDeactivationAnnotation, isNull,
          reason: 'consumed (saved) annotations must be cleared, not linger '
              'as if still pending');
    });

    test(
        'a failed deactivate() write does not save a stale annotation for a '
        'deactivation that never actually persisted', () async {
      final repo = InMemoryHistoryRepository();
      final n = IllnessModeNotifier(historyRepository: repo);
      await _settle();
      n.activate(boost: 1.5, notes: 'flu');
      await _settle();

      final unopenable = File('${Directory.systemTemp.path}/${'y' * 300}.db');
      KvStore.init(AppDatabase(NativeDatabase(unopenable)));

      n.deactivate();
      await _settle();

      expect(n.state.active, isTrue,
          reason: 'the write failed -- the UI-visible state must still show '
              'illness mode on (TASK-260)');
      final saved = await repo.annotations(DateTime(2020), DateTime(2030));
      expect(saved, isEmpty,
          reason: 'no annotation should be saved for a deactivation that '
              'never actually persisted -- illness mode is still active');
      expect(n.lastDeactivationAnnotation, isNull,
          reason: 'a failed persist must not leave a stale pending '
              'annotation for some future unrelated persist to pick up');
    });
  });
}

/// Minimal transport double — never actually invoked by the corrupt-restore test,
/// just satisfies GlucoseMeterController's/GlucoseMeterService's constructors.
class _NoopTransport implements GlucoseMeterTransport {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Stream<MeterDevice> scan({Duration timeout = const Duration(seconds: 12)}) =>
      const Stream.empty();
  @override
  Future<void> stopScan() async {}
  @override
  Future<List<GlucoseMeterReading>> fetchRecords(String deviceId, {int? sinceSeq}) =>
      throw UnimplementedError();
}
