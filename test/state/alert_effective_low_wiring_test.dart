/// TASK-231: the alert cycle and the coaching path (pre-bolus guard, rescue-carb
/// advice) both used to independently re-derive the composed low line from their own
/// carbs/profile/annotations/exercise/weather bundles -- two sites, one
/// `Duration(hours: 2)` post-meal literal each, free to silently diverge if only one
/// was updated. AlertCycleInput now carries the SAME `effectiveLowThresholdProvider`
/// value the coaching path reads. This proves the wiring end-to-end (not just that the
/// pure resolveEffectiveThresholds function passes through whatever it's given, which
/// would be true even if the provider wrapper fed it a stale/independent value): a
/// profile-driven low-line modifier changes whether a predicted-low decision fires.
library;

import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/insights/notification_prefs.dart';
import 'package:bgdude/ml/forecaster.dart';
import 'package:bgdude/profile/user_profile.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/faults.dart';
import '../support/samples.dart';

/// A fixed profile that never round-trips through KvStore -- setUp's empty
/// KvStore.useMemory() means the inherited restore-on-construct finds nothing to
/// load and leaves this assignment alone (see PersistedStateNotifier._restore's
/// `if (loaded == null) return`).
class _FixedUserProfile extends UserProfileNotifier {
  _FixedUserProfile(UserProfile profile) {
    state = profile;
  }
}

void main() {
  setUp(KvStore.useMemory);

  final now = DateTime(2026, 7, 8, 12);

  DayData dayData() => DayData(
        start: now.subtract(const Duration(hours: 24)),
        end: now,
        cgm: const [],
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: testTherapySettings(),
        context: null,
        isSimulated: false,
      );

  PredictionState stateAt(double mgdl) => PredictionState(
        now: now,
        currentMgdl: mgdl,
        recentRocMgdlPerMin: 0,
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: testTherapySettings(),
      );

  // 75 mg/dL sits ABOVE the default low line (70) but BELOW an impaired-awareness-
  // raised line (78 = 70 +5 age +3 duration, capped at +8 -- same fixture as
  // effective_low_threshold_test.dart's "impaired-awareness risk" case).
  final forecastAt75 = [
    HorizonForecast(horizonMinutes: 30, mgdl: 75, lowerMgdl: 65, upperMgdl: 85)
  ];

  ProviderContainer build({required UserProfile profile}) {
    final notifier = ThrowingNotificationService()..shouldThrow = false;
    final container = ProviderContainer(overrides: [
      notificationServiceProvider.overrideWithValue(notifier),
      pumpSnapshotProvider.overrideWith(
          (ref) => Stream.value(PumpSnapshot(time: now, cgmMgdl: 100))),
      dayDataProvider.overrideWithValue(dayData()),
      livePredictionStateProvider.overrideWithValue(stateAt(100)),
      calibratedForecastsProvider.overrideWithValue(forecastAt75),
      userProfileProvider.overrideWith((ref) => _FixedUserProfile(profile)),
      // effectiveLowThresholdProvider watches recentAnnotationsProvider, which by
      // default watches dayHistoryControllerProvider -- that outlives a single
      // onSnapshot() call and trips over container.dispose() (same issue documented
      // in alert_service_failure_injection_test.dart for rescueCarbAdviceProvider).
      // No annotations are relevant to this test's scenario, so short-circuit it.
      recentAnnotationsProvider.overrideWith((ref) async => const []),

      // Isolate the low-line modifier under test from the other effectiveLowThreshold
      // inputs (annotations/exercise/weather all default to none via these overrides'
      // absence + a memory-backed KvStore, and rescueCarbAdviceProvider pulling in
      // recentAnnotationsProvider -> the real dayHistoryControllerProvider would
      // outlive a single onSnapshot() call and trip over container.dispose()).
      rescueCarbAdviceProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  bool firedPredictedLow(ProviderContainer c) {
    final notifier =
        c.read(notificationServiceProvider) as ThrowingNotificationService;
    return notifier.shown.contains(NotificationCategory.predictedLow);
  }

  test('a default profile does not fire predicted-low at 75 mg/dL (above the '
      'unmodified 70 line)', () async {
    final container = build(profile: const UserProfile());

    await container.read(alertServiceProvider).onSnapshot();

    expect(firedPredictedLow(container), isFalse);
    // Sanity: the coaching path (same provider the alert cycle now reads) agrees.
    expect(container.read(effectiveLowThresholdProvider).mgdl, 70);
  });

  test('an impaired-awareness profile DOES fire predicted-low at the same 75 mg/dL '
      '-- the alert cycle picked up the coaching path\'s raised line, not a stale '
      'default', () async {
    final container =
        build(profile: const UserProfile(birthYear: 1950, diagnosisYear: 1990));

    await container.read(alertServiceProvider).onSnapshot();

    expect(firedPredictedLow(container), isTrue);
    // The alert fired because it used exactly this (coaching-path) line.
    expect(container.read(effectiveLowThresholdProvider).mgdl, 78);
  });
}
