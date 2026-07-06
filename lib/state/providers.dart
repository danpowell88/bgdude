/// Riverpod providers that wire the layers together and expose app state to the UI.
/// Kept hand-written (not codegen) so the wiring is readable at a glance.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alerts/alert_orchestrator.dart';
import '../analytics/band_coverage.dart';
import '../analytics/bolus_advisor.dart';
import '../analytics/context_builder.dart';
import '../analytics/insulin_math.dart';
import '../analytics/insulin_totals.dart';
import '../analytics/metrics.dart';
import '../analytics/predictor.dart';
import '../analytics/rescue_carbs.dart';
import '../analytics/therapy_settings.dart';
import '../core/samples.dart';
import '../core/units.dart';
import '../feedback/annotations.dart';
import '../feedback/confirmation_service.dart';
import '../feedback/pending_confirmation.dart';
import '../food/food_database.dart';
import '../food/offline_afcd.dart';
import '../food/open_food_facts.dart';
import '../food/panel_llm.dart';
import '../food/panel_llm_gemma.dart';
import '../food/panel_model_manager.dart';
import '../food/panel_ocr.dart';
import '../food/panel_ocr_mlkit.dart';
import '../food/panel_scan_service.dart';
import '../insights/a1c_goal.dart';
import '../insights/alcohol_watch.dart';
import '../insights/alert_thresholds.dart';
import '../insights/daily_narrative.dart';
import '../insights/exercise_mode.dart';
import '../insights/illness_mode.dart';
import '../insights/lab_a1c.dart';
import '../insights/medication_mode.dart';
import '../insights/sleep_insight.dart';
import '../insights/morning_summary.dart';
import '../insights/notification_prefs.dart';
import '../insights/notifications.dart';
import '../insights/post_meal_movement.dart';
import '../insights/workout_classifier.dart';
import '../profile/user_profile.dart';
import '../integrations/glucose_meter_controller.dart';
import '../integrations/glucose_meter_service.dart';
import '../integrations/glucose_meter_transport.dart';
import '../integrations/glucose_meter_transport_fbp.dart';
import '../integrations/nightscout.dart';
import '../logging/app_log.dart';
import '../logging/device_changes.dart';
import '../data/health_sync.dart';
import '../data/history_repository.dart';
import '../data/kv_store.dart';
import '../dev/demo_history.dart';
import '../dev/sim_data.dart';
import '../meals/meal_library.dart';
import '../meals/meal_log.dart';
import '../meals/meal_outcome_service.dart';
import '../meals/prebolus_coach.dart';
import '../ml/basal_recommender.dart';
import '../ml/forecast_features.dart';
import '../ml/forecaster.dart';
import '../ml/forecaster_service.dart';
import 'forecast_providers.dart';
import 'persisted_state_notifier.dart';
import '../ml/health_features.dart';
import '../ml/sensitivity_model.dart';
import '../ml/sensitivity_training.dart';
import '../ml/time_of_day_sensitivity.dart';
import '../ml/uncertainty_calibrator.dart';
import '../pump/battery_drain.dart';
import '../pump/battery_history.dart';
import '../pump/history_backfill.dart';
import '../pump/probe_event.dart';
import '../pump/pump_client.dart';
import '../pump/pump_events.dart';
import '../pump/pump_snapshot.dart';
import '../reports/correlation_report.dart';
import '../reports/cycle_report.dart';
import '../reports/events_journal.dart';
import '../reports/glucose_report.dart';
import '../reports/insulin_report.dart';
import '../reports/meals_report.dart';
import '../reports/model_report.dart';
import '../reports/report_range.dart';
import '../reports/therapy_report.dart';
import '../weather/weather.dart';
import '../weather/weather_history.dart';
import '../pump/pump_source.dart';
import '../pump/simulated_pump_client.dart';
import '../timeline/day_event.dart';
import '../timeline/event_builder.dart';
import '../widget/home_widget_service.dart';
import 'day_data.dart';
import 'day_history_controller.dart';

export 'day_data.dart';

/// Notification service (overridden in main() with the initialised instance).
final notificationServiceProvider =
    Provider<NotificationService>((ref) => throw UnimplementedError());

/// User notification preferences (categories, importance, sound/vibration, repeats),
/// persisted in the encrypted store. Changes are applied to the live channels.
final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
        (ref) => NotificationPrefsNotifier());

class NotificationPrefsNotifier extends PersistedStateNotifier<NotificationPrefs> {
  NotificationPrefsNotifier() : super(NotificationPrefs.defaults());
  static const _key = 'notification_prefs_v1';
  @override
  Future<NotificationPrefs?> load() async {
    final raw = await KvStore.getString(_key);
    return raw == null
        ? null
        : NotificationPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> store(NotificationPrefs v) =>
      KvStore.setString(_key, jsonEncode(v.toJson()));

  Future<void> setCategory(NotificationCategory c, CategoryPref pref) =>
      persist(state.withCategory(c, pref));

  Future<void> setQuietHours(QuietHours q) => persist(state.withQuietHours(q));
}

/// Whether barcode/food lookup may query Open Food Facts (an outbound request). On by
/// default; when off, only the bundled offline Australian food set is used. Persisted.
final barcodeLookupEnabledProvider =
    StateNotifierProvider<BarcodeLookupNotifier, bool>(
        (ref) => BarcodeLookupNotifier());

class BarcodeLookupNotifier extends PersistedStateNotifier<bool> {
  BarcodeLookupNotifier() : super(true);
  static const _key = 'barcode_lookup_enabled';
  @override
  Future<bool?> load() => KvStore.getBool(_key);
  @override
  Future<void> store(bool v) => KvStore.setBool(_key, v);

  Future<void> set(bool v) => persist(v);
}

/// The active food database: Open Food Facts (when lookup is enabled) for barcodes +
/// branded search, plus the bundled offline Australian generic set. Swappable/pluggable.
final foodDatabaseProvider = FutureProvider<FoodDatabase>((ref) async {
  final offline = await OfflineAfcdDatabase.load();
  final online = ref.watch(barcodeLookupEnabledProvider);
  return CompositeFoodDatabase([
    if (online) OpenFoodFactsDatabase(),
    offline,
  ]);
});

/// On-device OCR for the nutrition-panel photo reader (ML Kit; image stays on-device).
final panelOcrProvider = Provider<PanelOcr>((ref) => MlKitPanelOcr());

/// Optional small on-device LLM (Gemma) normaliser for panel OCR text — used only when a
/// model has been downloaded (see [panelModelProvider]); otherwise a no-op so the
/// deterministic parser is the sole path.
final panelLlmProvider = Provider<PanelLlmExtractor>((ref) =>
    ref.watch(panelModelProvider).installed
        ? const GemmaPanelExtractor()
        : const NoopPanelLlm());

/// State of the downloadable nutrition-panel LLM model.
class PanelModelStatus {
  const PanelModelStatus({
    required this.installed,
    this.url,
    this.downloading = false,
    this.progress = 0,
  });

  final bool installed;
  final String? url;
  final bool downloading;
  final int progress; // 0–100 while downloading

  PanelModelStatus copyWith(
          {bool? installed, String? url, bool? downloading, int? progress}) =>
      PanelModelStatus(
        installed: installed ?? this.installed,
        url: url ?? this.url,
        downloading: downloading ?? this.downloading,
        progress: progress ?? this.progress,
      );
}

final panelModelProvider =
    StateNotifierProvider<PanelModelController, PanelModelStatus>(
        (ref) => PanelModelController());

class PanelModelController extends StateNotifier<PanelModelStatus> {
  PanelModelController() : super(const PanelModelStatus(installed: false)) {
    _restore();
  }

  static const _urlKey = 'panel_llm_url_v1';
  final _mgr = const PanelModelManager();

  Future<void> _restore() async {
    final url = await KvStore.getString(_urlKey);
    if (url == null || url.isEmpty) return;
    final ok = await _mgr.isInstalled(url);
    if (mounted) state = PanelModelStatus(installed: ok, url: url);
  }

  /// Download + activate the model from [url] (with optional gated-download [token]).
  Future<void> download(String url, {String? token}) async {
    state = PanelModelStatus(
        installed: false, url: url, downloading: true, progress: 0);
    try {
      await _mgr.download(
        url: url,
        token: token,
        onProgress: (p) {
          if (mounted && state.downloading) {
            state = state.copyWith(progress: p);
          }
        },
      );
      await KvStore.setString(_urlKey, url);
      if (mounted) state = PanelModelStatus(installed: true, url: url);
    } catch (_) {
      if (mounted) {
        state = PanelModelStatus(installed: false, url: url, downloading: false);
      }
      rethrow;
    }
  }

  Future<void> remove() async {
    final url = state.url;
    if (url != null) await _mgr.delete(url);
    if (mounted) state = PanelModelStatus(installed: false, url: url);
  }
}

/// Reads a nutrition panel from a photo: OCR → deterministic parse → LLM fallback.
final panelScanServiceProvider = Provider<PanelScanService>((ref) =>
    PanelScanService(
        ocr: ref.watch(panelOcrProvider), llm: ref.watch(panelLlmProvider)));

/// The user's personal profile (sex, age, diabetes history, body metrics), persisted
/// encrypted. Fed into the models where usable (menstrual gating, hypo-awareness alerts).
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>(
        (ref) => UserProfileNotifier());

class UserProfileNotifier extends PersistedStateNotifier<UserProfile> {
  UserProfileNotifier() : super(const UserProfile());
  static const _key = 'user_profile_v1';
  @override
  Future<UserProfile?> load() async {
    final raw = await KvStore.getString(_key);
    return raw == null
        ? null
        : UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> store(UserProfile v) =>
      KvStore.setString(_key, jsonEncode(v.toJson()));

  Future<void> save(UserProfile profile) => persist(profile);
}

/// An announced exercise session (null when none). In-memory/transient — exercise is a
/// short-lived state. Raises the low-alert threshold while it's in effect.
final exercisePlanProvider = StateProvider<ExercisePlan?>((ref) => null);

/// User-customisable low/high glucose alert thresholds, persisted encrypted.
final alertThresholdsProvider =
    StateNotifierProvider<AlertThresholdsNotifier, AlertThresholds>(
        (ref) => AlertThresholdsNotifier());

class AlertThresholdsNotifier extends PersistedStateNotifier<AlertThresholds> {
  AlertThresholdsNotifier() : super(const AlertThresholds());
  static const _key = 'alert_thresholds_v1';
  @override
  Future<AlertThresholds?> load() async {
    final raw = await KvStore.getString(_key);
    return raw == null
        ? null
        : AlertThresholds.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> store(AlertThresholds t) =>
      KvStore.setString(_key, jsonEncode(t.toJson()));

  Future<void> save(AlertThresholds t) => persist(t);
}

/// Display unit (mmol/L default for the AU user), persisted encrypted so the choice
/// survives restarts. Set once during onboarding and changeable in Settings.
final glucoseUnitProvider =
    StateNotifierProvider<GlucoseUnitNotifier, GlucoseUnit>(
        (ref) => GlucoseUnitNotifier());

class GlucoseUnitNotifier extends PersistedStateNotifier<GlucoseUnit> {
  GlucoseUnitNotifier() : super(GlucoseUnit.mmol);
  static const _key = 'glucose_unit_v1';
  @override
  Future<GlucoseUnit?> load() async => switch (await KvStore.getString(_key)) {
        'mgdl' => GlucoseUnit.mgdl,
        'mmol' => GlucoseUnit.mmol,
        _ => null,
      };
  @override
  Future<void> store(GlucoseUnit v) =>
      KvStore.setString(_key, v == GlucoseUnit.mgdl ? 'mgdl' : 'mmol');

  Future<void> set(GlucoseUnit unit) => persist(unit);
}

/// Whether first-run onboarding (pairing warning + permission grants) is complete.
/// Initialized from shared_preferences in main(); flipping it persists the flag.
final onboardingDoneProvider = StateProvider<bool>((ref) => false);

/// Whether advanced mode (model internals, prediction decomposition) is enabled.
final advancedModeProvider = StateProvider<bool>((ref) => false);

/// Demo mode: run against the in-app t:slim + CGM simulator instead of the native pump
/// bridge, so the whole app is usable without hardware. Entered only via onboarding;
/// exited from the header / Settings. Persisted (prefs `dev_mode`) in main().
final devModeProvider = StateProvider<bool>((ref) => false);

/// P1-6: non-null with a message when the encrypted database failed to open and the app
/// fell back to an in-memory store (data not persisting). Overridden in `main()`.
final dbOpenErrorProvider = Provider<String?>((ref) => null);

/// The active pump data source — real native bridge, or the simulator in dev mode.
/// Recreated when [devModeProvider] flips so switching modes takes effect live.
final pumpClientProvider = Provider<PumpSource>((ref) {
  final devMode = ref.watch(devModeProvider);
  final PumpSource client =
      devMode ? SimulatedPumpClient() : PumpClient();
  client.start();
  ref.onDispose(client.dispose);
  return client;
});

/// The simulated day behind dev mode (null in real mode). Timeline/analytics read
/// history from here so they have content without a connected pump.
final simulatedDayProvider = Provider<SimulatedDay?>((ref) {
  if (!ref.watch(devModeProvider)) return null;
  final client = ref.watch(pumpClientProvider);
  return client is SimulatedPumpClient ? client.day : null;
});

/// Live connection state.
final pumpConnectionProvider = StreamProvider<PumpConnection>((ref) {
  final client = ref.watch(pumpClientProvider);
  return client.connection;
});

/// Live pump status snapshots (CGM, IOB, battery, …).
final pumpSnapshotProvider = StreamProvider<PumpSnapshot>((ref) {
  final client = ref.watch(pumpClientProvider);
  return client.snapshots;
});

/// Emits when the pump is waiting for a pairing code ('SHORT_6CHAR' | 'LONG_16CHAR').
final pumpPairingRequestProvider = StreamProvider<String>((ref) {
  return ref.watch(pumpClientProvider).pairingRequests;
});

/// Emits critical pump errors for surfacing to the user.
final pumpErrorProvider = StreamProvider<String>((ref) {
  return ref.watch(pumpClientProvider).errors;
});

/// Emits the pump's therapy profile JSON when auto-read from the pump (IDP import).
final pumpTherapyProfileProvider = StreamProvider<String>((ref) {
  return ref.watch(pumpClientProvider).therapyProfiles;
});

/// Protocol Explorer: raw probe messages (sent requests / received responses), captured
/// only while the explorer screen has enabled capture on the pump source.
final pumpProbeEventProvider = StreamProvider<ProbeEvent>((ref) {
  return ref.watch(pumpClientProvider).probeEvents;
});

/// The user's therapy settings (their pump IDP: basal schedule, ISF, CR, targets),
/// persisted. Feeds the what-if engine, bolus advisor, and predictions.
final therapySettingsProvider =
    StateNotifierProvider<TherapyNotifier, TherapySettings>(
        (ref) => TherapyNotifier());

class TherapyNotifier extends PersistedStateNotifier<TherapySettings> {
  TherapyNotifier() : super(TherapySettings.placeholder());
  static const _key = 'therapy_settings_v1';
  @override
  Future<TherapySettings?> load() async {
    final raw = await KvStore.getString(_key);
    return raw == null
        ? null
        : TherapySettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> store(TherapySettings v) =>
      KvStore.setString(_key, jsonEncode(v.toJson()));

  Future<void> save(TherapySettings settings) => persist(settings);
}

/// Today's sensitivity context (from the sensitivity model; neutral until trained).
final sensitivityContextProvider =
    StateProvider<SensitivityContext>((ref) => SensitivityContext.neutral);

/// Today's glycaemic metrics (TIR/GMI/CV) over the day's CGM.
final todayMetricsProvider = Provider<GlucoseMetrics>((ref) {
  final day = ref.watch(dayDataProvider);
  return const MetricsCalculator().compute(day.cgm);
});

/// The user's GMI (estimated A1c) goal, as a GMI percentage. Persisted.
final a1cTargetProvider =
    StateNotifierProvider<A1cTargetNotifier, double>((ref) => A1cTargetNotifier());

class A1cTargetNotifier extends PersistedStateNotifier<double> {
  A1cTargetNotifier() : super(6.5);
  static const _key = 'a1c_target_gmi';
  @override
  Future<double?> load() => KvStore.getDouble(_key);
  @override
  Future<void> store(double v) => KvStore.setDouble(_key, v);

  Future<void> save(double gmiPercent) => persist(gmiPercent);
}

/// GMI status + 2-week projection against the goal, over the last 14 days of CGM.
final a1cStatusProvider = FutureProvider<GmiStatus>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  final target = ref.watch(a1cTargetProvider);
  final now = DateTime.now();
  final cgm = await repo.cgm(now.subtract(const Duration(days: 14)), now);
  final recent = const MetricsCalculator().compute(cgm);
  // Group by calendar day and order chronologically (DateTime keys, not string keys —
  // a lexicographic sort would put day 10 before day 2 and scramble the trend).
  final byDay = <DateTime, List<double>>{};
  for (final s in cgm) {
    (byDay[DateTime(s.time.year, s.time.month, s.time.day)] ??= <double>[])
        .add(s.mgdl);
  }
  final keys = byDay.keys.toList()..sort();
  final means = [
    for (final k in keys)
      byDay[k]!.reduce((a, b) => a + b) / byDay[k]!.length,
  ];
  return const A1cTracker().status(
    recent: recent,
    dailyMeanMgdlHistory: means,
    targetGmiPercent: target,
  );
});

/// Manually entered lab HbA1c results (persisted). Compared to the CGM GMI to surface a
/// glycation gap.
final labA1cProvider =
    StateNotifierProvider<LabA1cNotifier, List<LabA1c>>((ref) => LabA1cNotifier());

class LabA1cNotifier extends StateNotifier<List<LabA1c>> {
  LabA1cNotifier() : super(const []) {
    _restore();
  }
  Future<void> _restore() async {
    state = await LabA1cStore.load();
  }

  Future<void> add(LabA1c entry) async {
    await LabA1cStore.add(entry);
    state = await LabA1cStore.load();
  }
}

/// The discordance between the latest lab A1c and the current CGM-derived GMI (null until
/// both exist).
final glycationGapProvider = Provider<GlycationGap?>((ref) {
  final labs = ref.watch(labA1cProvider);
  if (labs.isEmpty) return null;
  final gmi = ref.watch(a1cStatusProvider).valueOrNull?.currentGmiPercent;
  if (gmi == null) return null;
  return GlycationGap(labPercent: labs.last.percent, gmiPercent: gmi);
});

/// Sleep ↔ glucose-steadiness correlation over recent nights.
final sleepInsightProvider = FutureProvider<SleepInsight>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  final now = DateTime.now();
  final health = await repo.health(now.subtract(const Duration(days: 21)), now);
  final cgm = await repo.cgm(now.subtract(const Duration(days: 21)), now);
  final nights = <SleepNight>[];
  for (final h in health) {
    if (h.type != 'sleepHours') continue;
    final night = DateTime(h.time.year, h.time.month, h.time.day);
    final ws = night.add(const Duration(days: 1)); // next-morning window
    final we = ws.add(const Duration(hours: 7));
    final overnight = [
      for (final s in cgm)
        if (!s.time.isBefore(ws) && s.time.isBefore(we)) s,
    ];
    if (overnight.length < 12) continue;
    final m = const MetricsCalculator().compute(overnight);
    nights.add(SleepNight(
      night: night,
      sleepHours: h.value,
      overnightCvPercent: m.cvPercent,
      overnightTir: m.timeInRange,
    ));
  }
  return const SleepInsightAnalyzer().analyze(nights);
});

/// The "Your Day" narrative: a plain-language summary + suggestions built from the
/// current state, today's metrics, the sensitivity context, and the forecast.
final dailyNarrativeProvider = Provider<DailyNarrative>((ref) {
  final snap = ref.watch(pumpSnapshotProvider).valueOrNull;
  final metrics = ref.watch(todayMetricsProvider);
  final sensitivity = ref.watch(effectiveSensitivityProvider);
  final unit = ref.watch(glucoseUnitProvider);
  final state = ref.watch(livePredictionStateProvider);
  final illness = ref.watch(illnessModeProvider);
  final events = ref.watch(dayEventsProvider);

  double? low, high;
  if (state != null) {
    final f = ref.watch(forecasterProvider).forecastState(state);
    if (f.isNotEmpty) {
      low = f.map((e) => e.mgdl).reduce((a, b) => a < b ? a : b);
      high = f.map((e) => e.mgdl).reduce((a, b) => a > b ? a : b);
    }
  }
  final notable = events
      .where((e) =>
          e.type == DayEventType.high ||
          e.type == DayEventType.low ||
          e.type == DayEventType.detectedMeal)
      .length;

  return const DailyNarrativeGenerator().generate(DailyNarrativeInput(
    now: DateTime.now(),
    currentMgdl: snap?.cgmMgdl?.toDouble(),
    trend: snap?.cgmTrend ?? GlucoseTrend.unknown,
    todayMetrics: metrics,
    sensitivity: sensitivity,
    predictedLowMgdl: low,
    predictedHighMgdl: high,
    notableEventCount: notable,
    illnessActive: illness.active,
    unit: unit,
  ));
});

/// Shared engines.
final predictorProvider = Provider<GlucosePredictor>((ref) => GlucosePredictor());

/// The active learned residual model (deterministic-only until trained). The controller
/// loads the persisted model and runs the train → gate → promote cycle.
final forecasterModelProvider =
    StateNotifierProvider<ForecasterModelController, ResidualModel>(
        (ref) => ForecasterModelController());

final forecasterProvider = Provider<Forecaster>(
    (ref) => Forecaster(residual: ref.watch(forecasterModelProvider)));
final bolusAdvisorProvider = Provider<BolusAdvisor>(
    (ref) => BolusAdvisor(predictor: ref.watch(predictorProvider)));

/// Recent Google Fit / Health Connect activity (steps + workouts) as a sampler for the
/// live forecaster's activity features. Refreshed after each health sync; null (→ zero
/// features) until the first load or in dev mode where there's no wearable data.
final forecastHealthSamplerProvider =
    StateProvider<HealthFeatureSampler?>((ref) => null);

/// Rescue-carb advice when low or predicted-low (null when not needed).
final rescueCarbAdviceProvider = Provider<RescueCarbAdvice?>((ref) {
  final state = ref.watch(livePredictionStateProvider);
  if (state == null) return null;
  final seg = state.settings.segmentAt(state.now);
  final mult = state.context.effectiveMultiplier;
  // P0-5: rescue-carb sizing subtracts **bolus-only** IOB. Scheduled basal is
  // EGP-neutral (and Control-IQ-managed), so counting it would over-estimate the
  // insulin still pulling glucose down and over-treat the low.
  final iob =
      const IobCalculator().fromBoluses(state.boluses, state.now).units;
  final forecasts = ref.watch(forecasterProvider).forecastState(state);
  final nadir = forecasts.isEmpty
      ? null
      : forecasts.map((f) => f.mgdl).reduce((a, b) => a < b ? a : b);
  final advice = const RescueCarbCalculator().advise(
    currentMgdl: state.currentMgdl,
    targetMgdl: seg.targetMgdl,
    isf: seg.isf / mult,
    carbRatio: seg.carbRatio / mult,
    iobUnits: iob,
    predictedNadirMgdl: nadir,
    unit: ref.watch(glucoseUnitProvider),
  );
  return advice.needed ? advice : null;
});
final preBolusCoachProvider = Provider<PreBolusCoach>(
    (ref) => PreBolusCoach(predictor: ref.watch(predictorProvider)));

/// Home-screen widget bridge: pushed on every snapshot by the listener installed in
/// [BgDudeApp]; the staleness ticker keeps the "Xm ago" line honest between readings.
final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) {
  final service = HomeWidgetService()..startStalenessTicker();
  ref.onDispose(service.dispose);
  return service;
});

/// Learned time-of-day sensitivity profile (dawn phenomenon etc.). Null until the
/// nightly analysis job has ≥14 days of data to learn from.
final timeOfDayProfileProvider =
    StateProvider<TimeOfDayProfile?>((ref) => null);

/// Insulin delivered so far today (since local midnight): bolus + integrated basal.
/// Derived from our own history — a TDD-style running total for the Pump screen.
final insulinTodayProvider = Provider<InsulinTotals>((ref) {
  final day = ref.watch(dayDataProvider);
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  return insulinTotals(
      boluses: day.boluses, basal: day.basal, from: midnight, to: now);
});

/// Recent pump events (alarms/alerts/cartridge changes) decoded from the History Log.
final pumpEventsProvider =
    FutureProvider<List<PumpEvent>>((ref) => PumpEventLog.load());

/// Estimated pump-battery time-to-empty from the recent discharge slope (heuristic, not
/// ML). Re-reads when a new snapshot arrives.
final batteryDrainProvider = FutureProvider<BatteryDrainEstimate>((ref) async {
  ref.watch(pumpSnapshotProvider); // refresh alongside live status
  return const BatteryDrainEstimator()
      .estimate(await BatteryHistoryStore.load(), now: DateTime.now());
});

/// The date range the Reports section is showing (default: last 14 days).
final reportRangeProvider = StateProvider<ReportRange>(
    (ref) => ReportRange.preset(ReportPreset.last14, now: DateTime.now()));

/// The Glucose report for the selected range, plus the confirmed readings behind it
/// (kept alongside so PDF/CSV export shares exactly what the report shows). Built from
/// real, confirmed data — sensor-artifact windows are excluded.
final glucoseReportProvider =
    FutureProvider<({GlucoseReport report, List<CgmSample> confirmed})>(
        (ref) async {
  final range = ref.watch(reportRangeProvider);
  final repo = ref.watch(historyRepositoryProvider);
  final cgm = await repo.cgm(range.from, range.to);
  final annotations = await repo.annotations(range.from, range.to);
  final report = const GlucoseReportBuilder()
      .build(cgm: cgm, annotations: annotations, range: range, now: DateTime.now());
  final confirmed = GlucoseReportBuilder.confirmedSamples(
      cgm: cgm, annotations: annotations, range: range);
  return (report: report, confirmed: confirmed);
});

/// Insulin report (TDD trend, basal/bolus split, bolus behaviour) for the range.
final insulinReportProvider = FutureProvider<InsulinReport>((ref) async {
  final range = ref.watch(reportRangeProvider);
  final repo = ref.watch(historyRepositoryProvider);
  return const InsulinReportBuilder().build(
    boluses: await repo.boluses(range.from, range.to),
    basal: await repo.basal(range.from, range.to),
    range: range,
    now: DateTime.now(),
  );
});

/// Meals report (per-meal performance from confirmed outcomes) for the range.
final mealsReportProvider = Provider<MealsReport>((ref) {
  final range = ref.watch(reportRangeProvider);
  return const MealsReportBuilder().build(
    library: ref.watch(mealLibraryProvider),
    range: range,
    now: DateTime.now(),
  );
});

/// Post-meal movement correlation: your post-meal steps vs the size of the spike.
final postMealMovementProvider =
    FutureProvider<PostMealMovementResult>((ref) async {
  final range = ref.watch(reportRangeProvider);
  final library = ref.watch(mealLibraryProvider);
  final meals = [
    for (final m in library.meals)
      for (final o in m.outcomes)
        if (range.contains(o.eatenAt))
          (eatenAt: o.eatenAt, excursionMgdl: o.peakMgdl - o.bgAtMealMgdl),
  ];
  final steps = await ref
      .watch(historyRepositoryProvider)
      .health(range.from, range.to);
  return const PostMealMovementAnalyzer().analyze(meals: meals, steps: steps);
});

/// Therapy report (learned daily sensitivity trend via Autotune) for the range.
/// TASK-56: rolling 7-day forecast-band coverage (how often the actual reading landed inside
/// the predicted band). Keyed off the live state so it refreshes as new readings reconcile.
final bandCoverageProvider = FutureProvider<BandCoverage>((ref) async {
  ref.watch(livePredictionStateProvider); // refresh trigger as new readings flow in
  final repo = ref.watch(historyRepositoryProvider);
  final now = DateTime.now();
  final preds = await repo.predictions(now.subtract(const Duration(days: 7)), now);
  return computeBandCoverage([
    for (final p in preds)
      (actual: p.actualMgdl, lower: p.lowerMgdl, upper: p.upperMgdl),
  ]);
});

final therapyReportProvider = FutureProvider<TherapyReport>((ref) async {
  final range = ref.watch(reportRangeProvider);
  final repo = ref.watch(historyRepositoryProvider);
  final from = range.from.subtract(const Duration(hours: 6)); // IOB lookback
  return TherapyReportBuilder().build(
    cgm: await repo.cgm(from, range.to),
    boluses: await repo.boluses(from, range.to),
    basal: await repo.basal(from, range.to),
    carbs: await repo.carbs(from, range.to),
    settings: ref.read(therapySettingsProvider),
    range: range,
    now: DateTime.now(),
  );
});

/// Correlation report: daily glycemic outcomes vs confirmed lifestyle inputs.
final correlationReportProvider =
    FutureProvider<CorrelationReport>((ref) async {
  final range = ref.watch(reportRangeProvider);
  final repo = ref.watch(historyRepositoryProvider);
  return const CorrelationReportBuilder().build(
    cgm: await repo.cgm(range.from, range.to),
    health: await repo.health(range.from, range.to),
    range: range,
    now: DateTime.now(),
    dailyTempC: await WeatherHistoryStore.loadDaily(),
    annotations: await repo.annotations(range.from, range.to),
  );
});

/// Menstrual-cycle glucose comparison (follicular vs luteal) for the range. Only computed
/// for profiles with a menstrual cycle.
final cycleReportProvider = FutureProvider<CycleReport>((ref) async {
  final range = ref.watch(reportRangeProvider);
  final now = DateTime.now();
  if (!ref.watch(userProfileProvider).hasMenstrualCycle) {
    return const CycleReportBuilder().build(
        cgm: [], health: [], range: range, now: now);
  }
  final repo = ref.watch(historyRepositoryProvider);
  return const CycleReportBuilder().build(
    cgm: await repo.cgm(range.from, range.to),
    health: await repo.health(range.from, range.to),
    range: range,
    now: now,
  );
});

/// Model-performance report: forecast accuracy, Clarke zones, interval calibration.
final modelReportProvider = FutureProvider<ModelReport>((ref) async {
  final range = ref.watch(reportRangeProvider);
  final repo = ref.watch(historyRepositoryProvider);
  final now = DateTime.now();
  try {
    await repo.reconcilePredictions(now); // back-fill actuals before scoring
  } catch (_) {}
  return const ModelReportBuilder().build(
    predictions: await repo.predictions(range.from, range.to),
    modelRuns: await repo.modelRuns(),
    range: range,
    now: now,
  );
});

/// Events journal: a merged, newest-first timeline of confirmed events for the range.
final eventsJournalProvider = FutureProvider<List<JournalEntry>>((ref) async {
  final range = ref.watch(reportRangeProvider);
  final repo = ref.watch(historyRepositoryProvider);
  final glucose = await ref.watch(glucoseReportProvider.future);
  return const EventsJournalBuilder().build(
    range: range,
    annotations: await repo.annotations(range.from, range.to),
    pumpEvents: await PumpEventLog.load(),
    deviceChanges: ref.read(deviceStateProvider).changes,
    lowEpisodes: glucose.report.lowEpisodes,
    highEpisodes: glucose.report.highEpisodes,
    unit: ref.read(glucoseUnitProvider),
  );
});

/// Suggested basal-profile changes derived from repeated time-of-day sensitivity
/// trends. Empty until there's a trusted profile (≥14 days). Informational only —
/// never writes to the pump.
final basalRecommendationProvider = Provider<BasalRecommendation>((ref) {
  final profile = ref.watch(timeOfDayProfileProvider);
  final settings = ref.watch(therapySettingsProvider);
  final now = DateTime.now();
  if (profile == null) return BasalRecommendation.none(now);
  return const BasalRecommender()
      .recommend(profile: profile, settings: settings, now: now);
});

/// A pending illness-mode suggestion from the detector (null when none). Surfaced in the
/// Confirm-events inbox (and a notification); confirming it turns illness mode on.
final illnessSuggestionProvider =
    StateProvider<IllnessSuggestion?>((ref) => null);

/// The Confirmation Inbox: detected-but-unconfirmed events (unannounced meals,
/// compression lows, illness) over recent history, minus anything already decided or
/// annotated. Confirming/dismissing goes through [AppJobs.confirmPending]/[dismissPending].
final pendingConfirmationsProvider =
    FutureProvider<List<PendingConfirmation>>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  // P2-9: re-scan when a new CGM reading lands (watch only the CGM timestamp so IOB/age
  // ticks on the same snapshot don't force a rescan).
  ref.watch(pumpSnapshotProvider.select((s) => s.valueOrNull?.cgmTime));
  final now = DateTime.now();
  final from = now.subtract(const Duration(days: 3));
  final decided = (await ConfirmationDecisionStore.load()).keys.toSet();
  return const ConfirmationService().scan(
    now: now,
    cgm: await repo.cgm(from, now),
    boluses: await repo.boluses(from, now),
    basal: await repo.basal(from, now),
    carbs: await repo.carbs(from, now),
    settings: ref.read(therapySettingsProvider),
    annotations: await repo.annotations(from, now),
    decidedIds: decided,
    illness: ref.watch(illnessSuggestionProvider),
  );
});

/// Illness ("sick day") mode with shared_preferences persistence.
final illnessModeProvider =
    StateNotifierProvider<IllnessModeNotifier, IllnessMode>(
        (ref) => IllnessModeNotifier());

class IllnessModeNotifier extends StateNotifier<IllnessMode> {
  IllnessModeNotifier() : super(IllnessMode.inactive) {
    _restore();
  }

  static const _prefsKey = 'illness_mode_v1';
  final IllnessModeController _controller = IllnessModeController();

  /// The annotation emitted by the most recent deactivation, for the data layer to
  /// persist into the feedback store.
  Annotation? lastDeactivationAnnotation;

  Future<void> _restore() async {
    final raw = await KvStore.getString(_prefsKey);
    if (raw != null) {
      _controller.mode = IllnessMode.decode(raw);
      state = _controller.mode;
    }
  }

  Future<void> _persist() async {
    await KvStore.setString(_prefsKey, _controller.mode.encode());
    state = _controller.mode;
  }

  void activate({double? boost, String? notes}) {
    _controller.activate(
      now: DateTime.now(),
      expectedResistanceBoost: boost,
      notes: notes,
    );
    unawaited(_persist());
  }

  void deactivate() {
    lastDeactivationAnnotation = _controller.deactivate(DateTime.now());
    unawaited(_persist());
  }

  void updateBoost(double boost) {
    _controller.updateBoost(boost);
    unawaited(_persist());
  }

  /// The overlay applied to the model-derived context while sick.
  SensitivityContext overlay(SensitivityContext base) =>
      _controller.overlay(base);

  List<String> get adviceNotes => _controller.adviceNotes;
}

/// The sensitivity context the advisor/predictor should actually use: the daily
/// model context, refined by the learned time-of-day profile, then overlaid with
/// illness mode when active. Watch THIS, not [sensitivityContextProvider], anywhere
/// dosing math happens.
final effectiveSensitivityProvider = Provider<SensitivityContext>((ref) {
  var daily = ref.watch(sensitivityContextProvider);
  // Before the model is trained, fall back to the transparent context heuristic so
  // sleep/HRV/illness still inform dosing and insights (and dev mode looks alive).
  if (daily.confidence == 0) {
    final features = ref.watch(contextFeaturesProvider);
    if (features != null) daily = heuristicSensitivity(features);
  }

  final profile = ref.watch(timeOfDayProfileProvider);
  final illness = ref.watch(illnessModeProvider.notifier);
  // Re-evaluate when illness mode toggles.
  ref.watch(illnessModeProvider);

  var ctx = daily;
  if (profile != null && !profile.isNeutral) {
    ctx = profile.contextAt(DateTime.now(), daily: ctx);
  }
  ctx = illness.overlay(ctx);
  // A medication (e.g. steroid) course raises resistance on top of everything else.
  return ref.watch(medicationModeProvider).overlay(ctx);
});

/// A medication/steroid course that raises insulin resistance while active. Persisted.
final medicationModeProvider =
    StateNotifierProvider<MedicationModeNotifier, MedicationMode>(
        (ref) => MedicationModeNotifier());

class MedicationModeNotifier extends StateNotifier<MedicationMode> {
  MedicationModeNotifier() : super(const MedicationMode()) {
    _restore();
  }
  static const _key = 'medication_mode_v1';

  Future<void> _restore() async {
    final raw = await KvStore.getString(_key);
    if (raw != null) {
      state = MedicationMode.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  Future<void> _persist() async =>
      KvStore.setString(_key, jsonEncode(state.toJson()));

  Future<void> start(MedicationIntensity intensity, {String name = 'Steroid'}) async {
    state = MedicationMode(
        active: true, startedAt: DateTime.now(), intensity: intensity, name: name);
    await _persist();
  }

  Future<void> stop() async {
    state = state.copyWith(active: false, startedAt: null);
    await _persist();
  }

  /// Remember the intensity choice without (de)activating.
  Future<void> setIntensity(MedicationIntensity intensity) async {
    state = state.copyWith(intensity: intensity);
    await _persist();
  }
}

/// The real, persisted history repository. Overridden in main() with a SQLCipher-backed
/// [DriftHistoryRepository]; defaults to in-memory so tests and DB-less contexts work.
final persistentHistoryRepositoryProvider =
    Provider<HistoryRepository>((ref) => InMemoryHistoryRepository());

/// A throwaway in-memory repository pre-seeded with ~3 weeks of simulated history, used
/// only in demo mode so every range-based report/insight has data. Never persisted.
final demoHistoryRepositoryProvider = Provider<HistoryRepository>((ref) {
  final repo = InMemoryHistoryRepository();
  final bundle = DemoHistory.build(now: DateTime.now());
  repo.seed(
    cgm: bundle.cgm,
    boluses: bundle.boluses,
    carbs: bundle.carbs,
    basal: bundle.basal,
    health: bundle.health,
    annotations: bundle.annotations,
    predictions: bundle.predictions,
  );
  return repo;
});

/// The history repository the app reads/writes. In demo mode this is the seeded in-memory
/// store (so demo data never lands in the real database); otherwise the persistent one.
final historyRepositoryProvider = Provider<HistoryRepository>((ref) =>
    ref.watch(devModeProvider)
        ? ref.watch(demoHistoryRepositoryProvider)
        : ref.watch(persistentHistoryRepositoryProvider));

/// Health Connect ingestion service.
final healthSyncServiceProvider =
    Provider<HealthSyncService>((ref) => HealthSyncService());

final weatherServiceProvider = Provider<WeatherService>((ref) => WeatherService());

/// Weather settings (city → lat/lon, enabled). Persisted; opt-in (nothing is fetched
/// until a city is set and it's enabled).
final weatherSettingsProvider =
    StateNotifierProvider<WeatherSettingsNotifier, WeatherSettings>(
        (ref) => WeatherSettingsNotifier());

class WeatherSettingsNotifier extends PersistedStateNotifier<WeatherSettings> {
  WeatherSettingsNotifier() : super(const WeatherSettings());
  static const _key = 'weather_settings_v1';
  @override
  Future<WeatherSettings?> load() async {
    final raw = await KvStore.getString(_key);
    return raw == null
        ? null
        : WeatherSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> store(WeatherSettings v) =>
      KvStore.setString(_key, jsonEncode(v.toJson()));

  Future<void> save(WeatherSettings s) => persist(s);
}

/// Current ambient weather (null unless enabled + a location is set). Records the reading
/// into the daily weather history for correlation.
final weatherProvider = FutureProvider<Weather?>((ref) async {
  final s = ref.watch(weatherSettingsProvider);
  if (!s.ready) return null;
  final w = await ref.read(weatherServiceProvider).current(s.lat!, s.lon!);
  if (w != null) {
    try {
      await WeatherHistoryStore.record(w.at, w.tempC);
    } catch (_) {}
  }
  return w;
});

/// Owns "today": assembled from the repository and kept live as snapshots arrive.
/// Seeds from the simulator in dev mode.
final dayHistoryControllerProvider =
    StateNotifierProvider<DayHistoryController, DayData>((ref) {
  final controller = DayHistoryController(
    repo: ref.watch(historyRepositoryProvider),
    settings: ref.watch(therapySettingsProvider),
    sim: ref.watch(simulatedDayProvider),
  );
  return controller;
});

/// The day's data (history + events + context). Watch this for anything that needs
/// history; it is the single source of truth, kept live by [DayHistoryController].
final dayDataProvider =
    Provider<DayData>((ref) => ref.watch(dayHistoryControllerProvider));

/// The day's health context features (sleep/HRV/etc.), when available.
final contextFeaturesProvider = Provider<ContextFeatures?>((ref) {
  return ref.watch(dayDataProvider).context;
});

/// User tags over timeline events: eventId → (disposition, reason). Overlaid on the
/// derived events so the model-inclusion choice survives rebuilds. Ignored events
/// yield annotations for the retraining pipeline.
final eventDispositionProvider = StateNotifierProvider<EventDispositionNotifier,
    Map<String, ({ModelDisposition disposition, IgnoreReason? reason})>>(
  (ref) => EventDispositionNotifier(),
);

class EventDispositionNotifier extends StateNotifier<
    Map<String, ({ModelDisposition disposition, IgnoreReason? reason})>> {
  EventDispositionNotifier() : super({});

  void use(String eventId) {
    state = {...state, eventId: (disposition: ModelDisposition.use, reason: null)};
  }

  void ignore(String eventId, IgnoreReason reason) {
    state = {
      ...state,
      eventId: (disposition: ModelDisposition.ignore, reason: reason),
    };
  }

  void clear(String eventId) {
    final next = {...state}..remove(eventId);
    state = next;
  }
}

/// The day's event stream (meals, boluses, detected rises, highs/lows, compression
/// lows, sensor/site changes) with any user tags applied. Timeline's single source.
final dayEventsProvider = Provider<List<DayEvent>>((ref) {
  final day = ref.watch(dayDataProvider);
  final unit = ref.watch(glucoseUnitProvider);
  final overrides = ref.watch(eventDispositionProvider);
  final devices = ref.watch(deviceStateProvider);

  final events = [...EventBuilder(unit: unit).build(day)];

  // Sensor/site changes that happened within today's window.
  for (final c in devices.changes) {
    if (c.changedAt.isBefore(day.start) || c.changedAt.isAfter(day.end)) continue;
    events.add(DayEvent(
      id: '${c.kind.name}-${c.changedAt.millisecondsSinceEpoch}',
      type: c.kind == DeviceKind.sensor
          ? DayEventType.sensorChange
          : DayEventType.siteChange,
      time: c.changedAt,
      title: 'Changed ${c.kind.label.toLowerCase()}',
      detail: c.kind == DeviceKind.sensor
          ? 'Readings may be unreliable during the warm-up window.'
          : 'Fresh site — watch the first few hours for absorption changes.',
    ));
  }

  return [
    for (final e in events)
      if (overrides.containsKey(e.id))
        e.copyWith(
          disposition: overrides[e.id]!.disposition,
          ignoreReason: overrides[e.id]!.reason,
        )
      else
        e,
  ];
});

/// The live physiological state every prediction/advice call starts from: the latest
/// CGM reading + the day's insulin/carb history + therapy settings + the EFFECTIVE
/// sensitivity context (time-of-day + illness applied). Null until a reading exists.
///
/// Single source of truth — screens must not hand-assemble PredictionState, or they
/// silently skip the history and context overlays.
final livePredictionStateProvider = Provider<PredictionState?>((ref) {
  final day = ref.watch(dayDataProvider);
  final snapshot = ref.watch(pumpSnapshotProvider).valueOrNull;
  final latest = day.latest ?? snapshot?.toCgmSample();
  if (latest == null) return null;

  final roc = day.recentRocMgdlPerMin() ??
      (snapshot?.cgmTrend ?? GlucoseTrend.flat).mgdlPerMin;

  final healthSampler = ref.watch(forecastHealthSamplerProvider);

  // TASK-72: never let the advisor suggest more than the pump's own configured max bolus.
  var settings = day.settings;
  final pumpMaxBolus = snapshot?.maxBolusUnits;
  if (pumpMaxBolus != null && pumpMaxBolus < settings.maxBolusUnits) {
    settings = settings.copyWith(maxBolusUnits: pumpMaxBolus);
  }

  return PredictionState(
    now: latest.time,
    currentMgdl: latest.mgdl,
    recentRocMgdlPerMin: roc,
    boluses: day.boluses,
    basal: day.basal,
    carbs: day.carbs,
    settings: settings,
    context: ref.watch(effectiveSensitivityProvider),
    healthFeatures:
        healthSampler?.featuresAt(latest.time) ?? HealthFeatureSampler.zeros,
    controlIq: _controlIqStateFrom(snapshot),
  );
});

/// Map the live pump snapshot's Control-IQ status onto the closed-loop model the
/// predictor/advisor use. Off unless the loop is actually enabled.
ControlIqState _controlIqStateFrom(PumpSnapshot? snap) {
  if (snap == null) return ControlIqState.off;
  final on = snap.closedLoopEnabled ?? snap.controlIqActive ?? false;
  if (!on) return ControlIqState.off;
  return switch (snap.controlIqMode) {
    ControlIqMode.sleep => ControlIqState.sleep,
    ControlIqMode.exercise => ControlIqState.exercise,
    // Standard, or unknown-but-active firmware → treat as Standard.
    _ => ControlIqState.standard,
  };
}

/// Saved-meal library with shared_preferences persistence (the drift `SavedMeals`
/// table is the eventual home once the encrypted DB is wired through the app).
final mealLibraryProvider =
    StateNotifierProvider<MealLibraryNotifier, MealLibrary>(
        (ref) => MealLibraryNotifier(demo: ref.watch(devModeProvider)));

class MealLibraryNotifier extends StateNotifier<MealLibrary> {
  MealLibraryNotifier({this.demo = false}) : super(MealLibrary()) {
    _restore();
  }

  /// In demo mode, seed a few saved meals (with outcome history) when the store is empty
  /// so the meal library and Meals report have content without hardware.
  final bool demo;

  static const _prefsKey = 'meal_library_v1';

  Future<void> _restore() async {
    final raw = await KvStore.getStringList(_prefsKey);
    if ((raw == null || raw.isEmpty) && demo) {
      state = MealLibrary(meals: DemoHistory.demoMeals(now: DateTime.now()));
      return;
    }
    if (raw != null && raw.isNotEmpty) {
      state = MealLibrary(
        meals: [
          for (final r in raw)
            SavedMeal.fromJson(jsonDecode(r) as Map<String, dynamic>),
        ],
      );
    }
  }

  Future<void> _persist() async {
    await KvStore.setStringList(
      _prefsKey,
      [for (final m in state.meals) jsonEncode(m.toJson())],
    );
  }

  void add(SavedMeal meal) {
    state.add(meal);
    state = MealLibrary(meals: state.meals);
    unawaited(_persist());
  }

  void learnFromOutcome(
    SavedMeal meal,
    MealOutcome outcome,
    List<CgmSample> postMealCgm,
  ) {
    state.learnFromOutcome(meal, outcome, postMealCgm);
    state = MealLibrary(meals: state.meals);
    unawaited(_persist());
  }
}

/// Log of meals actually eaten, awaiting outcome learning.
final mealLogProvider =
    StateNotifierProvider<MealLogNotifier, List<MealLogEntry>>(
        (ref) => MealLogNotifier());

class MealLogNotifier extends StateNotifier<List<MealLogEntry>> {
  MealLogNotifier() : super(const []) {
    _restore();
  }

  Future<void> _restore() async {
    state = await MealLogStore.load();
  }

  Future<void> add(MealLogEntry entry) async {
    state = [...state, entry];
    await MealLogStore.save(state);
  }

  Future<void> replaceAll(List<MealLogEntry> entries) async {
    state = entries;
    await MealLogStore.save(state);
  }
}

/// Nightscout upload configuration (persisted) and client.
final nightscoutConfigProvider =
    StateNotifierProvider<NightscoutConfigNotifier, NightscoutConfig>(
        (ref) => NightscoutConfigNotifier());

class NightscoutConfigNotifier extends PersistedStateNotifier<NightscoutConfig> {
  NightscoutConfigNotifier() : super(const NightscoutConfig());
  static const _key = 'nightscout_config_v1';
  @override
  Future<NightscoutConfig?> load() async {
    final raw = await KvStore.getString(_key);
    return raw == null
        ? null
        : NightscoutConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> store(NightscoutConfig v) =>
      KvStore.setString(_key, jsonEncode(v.toJson()));

  Future<void> save(NightscoutConfig config) => persist(config);
}

final nightscoutClientProvider = Provider<NightscoutClient>(
    (ref) => NightscoutClient(ref.watch(nightscoutConfigProvider)));

/// Bluetooth glucose-meter import (standard GLS, e.g. Accu-Chek Guide Me).
final glucoseMeterTransportProvider =
    Provider<GlucoseMeterTransport>((ref) => FbpGlucoseMeterTransport());

final glucoseMeterServiceProvider = Provider<GlucoseMeterService>((ref) =>
    GlucoseMeterService(
        transport: ref.watch(glucoseMeterTransportProvider),
        repository: ref.watch(historyRepositoryProvider)));

final glucoseMeterProvider =
    StateNotifierProvider<GlucoseMeterController, GlucoseMeterStatus>((ref) =>
        GlucoseMeterController(
          service: ref.watch(glucoseMeterServiceProvider),
          transport: ref.watch(glucoseMeterTransportProvider),
          demo: ref.watch(devModeProvider),
        ));

/// CGM sensor / infusion-site change tracking.
final deviceStateProvider =
    StateNotifierProvider<DeviceChangeNotifier, DeviceState>(
        (ref) => DeviceChangeNotifier());

class DeviceChangeNotifier extends StateNotifier<DeviceState> {
  DeviceChangeNotifier() : super(const DeviceState()) {
    _restore();
  }

  Future<void> _restore() async {
    state = await DeviceChangeStore.load();
  }

  Future<void> record(DeviceKind kind, {DateTime? at}) async {
    state = state.withChange(DeviceChange(kind: kind, changedAt: at ?? DateTime.now()));
    await DeviceChangeStore.save(state);
  }
}

/// Recent per-horizon live forecast error (mg/dL RMSE), used to widen the prediction
/// cone. Updated by the jobs runner after prediction reconciliation.
final recentHorizonErrorProvider =
    StateProvider<Map<int, double>>((ref) => const {});

/// Alerts the user when the pump has been disconnected for a sustained period.
final connectionAlertServiceProvider =
    Provider<ConnectionAlertService>((ref) => ConnectionAlertService(ref));

class ConnectionAlertService {
  ConnectionAlertService(this._ref);
  final Ref _ref;
  Timer? _timer;

  static const graceBeforeAlert = Duration(minutes: 10);

  void onConnection(PumpConnection c) {
    if (c.stage == PumpConnectionStage.connected) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (c.stage == PumpConnectionStage.disconnected ||
        c.stage == PumpConnectionStage.error) {
      _timer ??= Timer(graceBeforeAlert, () async {
        _timer = null;
        try {
          await _ref.read(notificationServiceProvider).show(
                NotificationCategory.connectionLost,
                'Pump disconnected',
                'No pump data for ~10 min — readings and predictions are paused. '
                    'Check Bluetooth and that the pump is in range.',
              );
        } catch (_) {}
      });
    }
  }
}

/// Fires real-time predicted-low/high nudges and logs predictions for accuracy
/// scoring. Driven from the app root on each pump snapshot.
final alertServiceProvider = Provider<AlertService>((ref) => AlertService(ref));

class AlertService {
  AlertService(this._ref);
  final Ref _ref;
  final Map<NotificationCategory, DateTime> _lastFired = {};
  DateTime? _lastPredictionLog;

  /// Gate on the category's enabled state and repeat interval (repeatMinutes; a category
  /// with repeat 0 uses a 30-min re-alert floor so a persistent condition isn't silent
  /// forever, but doesn't spam).
  /// Whether [c]'s repeat cooldown has elapsed. Pure — does NOT record a fire, so a send
  /// that then fails won't suppress the next attempt (critical for urgent lows, TASK-38).
  bool _coolPassed(NotificationCategory c, DateTime now) {
    final pref = _ref.read(notificationPrefsProvider).of(c);
    if (!pref.enabled) return false;
    final interval =
        Duration(minutes: pref.repeatMinutes > 0 ? pref.repeatMinutes : 30);
    final last = _lastFired[c];
    return last == null || now.difference(last) >= interval;
  }

  void _markFired(NotificationCategory c, DateTime now) => _lastFired[c] = now;

  /// Cooldown check that also records the fire immediately. Kept for the non-critical
  /// alerts where an optimistic mark is fine; the urgent path uses [_coolPassed] +
  /// [_markFired] so a failed send is retried.
  bool _shouldFire(NotificationCategory c, DateTime now) {
    if (!_coolPassed(c, now)) return false;
    _markFired(c, now);
    return true;
  }

  /// Gather one cycle's inputs as values, run the pure [AlertOrchestrator], then own
  /// the side effects: cooldown/dedup gating, `NotificationService.show`, battery
  /// history I/O and throttled prediction logging (TASK-116).
  Future<void> onSnapshot() async {
    final now = DateTime.now();
    final snap = _ref.read(pumpSnapshotProvider).valueOrNull;

    // Battery history I/O stays here; the low/soon-empty decision is pure.
    var batterySamples = const <BatterySample>[];
    final batteryPct = snap?.batteryPercent;
    if (batteryPct != null) {
      try {
        await BatteryHistoryStore.append(BatterySample(
            time: now, percent: batteryPct, charging: snap!.isCharging));
      } catch (e) { appLog.error('alerts', 'battery history append failed', error: e); }
      batterySamples = await BatteryHistoryStore.load();
    }

    final state = _ref.read(livePredictionStateProvider);
    var forecasts = const <HorizonForecast>[];
    DayData? day;
    UserProfile? profile;
    Iterable<Annotation> recentAnnotations = const <Annotation>[];
    ExercisePlan? exercise;
    double? ambientTempC;
    RescueCarbAdvice? rescue;
    double? siteAgeHours;
    var illnessActive = false;
    var activity = 0.0;
    if (state != null) {
      forecasts = const UncertaintyCalibrator().calibrateAll(
        _ref.read(forecasterProvider).forecastState(state),
        _ref.read(recentHorizonErrorProvider),
      );
      day = _ref.read(dayDataProvider);
      profile = _ref.read(userProfileProvider);
      const alcohol = AlcoholWatch();
      recentAnnotations = await _ref
          .read(historyRepositoryProvider)
          .annotations(now.subtract(alcohol.window), now);
      exercise = _ref.read(exercisePlanProvider);
      ambientTempC = _ref.read(weatherProvider).valueOrNull?.tempC;
      rescue = _ref.read(rescueCarbAdviceProvider);
      final siteMin =
          _ref.read(deviceStateProvider).age(DeviceKind.site, now)?.inMinutes;
      siteAgeHours = siteMin == null ? null : siteMin / 60.0;
      illnessActive = _ref.read(illnessModeProvider).active;
      activity =
          _ref.read(forecastHealthSamplerProvider)?.featuresAt(now).first ?? 0.0;
    }

    final result = const AlertOrchestrator().evaluate(AlertCycleInput(
      now: now,
      snapshot: snap,
      lastAlarmSignature: _lastAlarmSignature,
      batterySamples: batterySamples,
      state: state,
      forecasts: forecasts,
      unit: _ref.read(glucoseUnitProvider),
      thresholds: _ref.read(alertThresholdsProvider),
      day: day,
      profile: profile,
      recentAnnotations: recentAnnotations,
      exercise: exercise,
      ambientTempC: ambientTempC,
      rescue: rescue,
      siteAgeHours: siteAgeHours,
      illnessActive: illnessActive,
      recentActivityFeature: activity,
    ));
    _lastAlarmSignature = result.alarmSignature;

    for (final d in result.decisions) {
      // A critical decision checks the cooldown here and records the fire only after
      // a successful send (so a failed urgent-low is retried next cycle, TASK-38);
      // normal decisions record optimistically. bypassCooldown (a NEW pump alarm)
      // fires regardless and leaves the repeat cooldown untouched.
      final fire = d.bypassCooldown ||
          (d.urgency == AlertUrgency.critical
              ? _coolPassed(d.category, now)
              : _shouldFire(d.category, now));
      if (!fire) continue;
      try {
        await _ref
            .read(notificationServiceProvider)
            .show(d.category, d.title, d.body, bigText: d.bigText);
        if (d.urgency == AlertUrgency.critical) _markFired(d.category, now);
      } catch (e) {
        appLog.error('alerts', 'send failed: ${d.category.name}', error: e);
      }
    }

    // Log predictions (throttled) so the model-accuracy view can score them later.
    if (state != null &&
        (_lastPredictionLog == null ||
            now.difference(_lastPredictionLog!).inMinutes >= 5)) {
      _lastPredictionLog = now;
      final trained = _ref.read(forecasterModelProvider).isTrained;
      final repo = _ref.read(historyRepositoryProvider);
      for (final f in forecasts) {
        try {
          await repo.savePrediction(StoredPrediction(
            madeAt: state.now,
            horizonMinutes: f.horizonMinutes,
            predictedMgdl: f.mgdl,
            lowerMgdl: f.lowerMgdl,
            upperMgdl: f.upperMgdl,
            modelId: trained ? 'residual' : 'deterministic',
          ));
        } catch (e) { appLog.error('alerts', 'prediction log failed', error: e); }
      }
    }
  }

  /// Signature of the pump's active alarm/alert set last cycle, so a CHANGED set
  /// re-alerts immediately (see AlertOrchestrator).
  String? _lastAlarmSignature;
}

/// Background jobs run at startup (and on demand): close the meal-outcome loop,
/// reconcile matured predictions, and retrain the forecaster when enough data exists.
final appJobsProvider = Provider<AppJobs>((ref) => AppJobs(ref));

class AppJobs {
  AppJobs(this._ref);
  final Ref _ref;

  Future<void> runStartup() async {
    // Each job is independent and best-effort — one failing must not abort the rest — but a
    // failure is now recorded so a job that silently never runs is diagnosable (TASK-38).
    Future<void> job(String name, Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        appLog.error('startup', 'job "$name" failed', error: e);
      }
    }

    // TASK-24: push the current display unit to the Garmin watch once at launch (the live
    // listener only fires on subsequent changes).
    await job('garminUnit', () async =>
        _ref.read(pumpClientProvider).setGarminUnit(_ref.read(glucoseUnitProvider)));
    if (!_ref.read(devModeProvider)) {
      await job('syncHealth', syncHealth);
    }
    await job('refreshForecastHealthSampler', refreshForecastHealthSampler);
    await job('runMealOutcomeLoop', runMealOutcomeLoop);
    await job('reconcilePredictions', () async {
      await _ref.read(historyRepositoryProvider).reconcilePredictions(DateTime.now());
      await updateRecentForecastError();
    });
    // TASK-62: keep the DB lean — prune stale predictions/health (CGM + insulin kept).
    await job('pruneOldData',
        () => _ref.read(historyRepositoryProvider).pruneOldData(DateTime.now()));
    await job('maybeShowMorningSummary', maybeShowMorningSummary);
    await job('checkDeviceReminders', checkDeviceReminders);
    if (!_ref.read(devModeProvider)) {
      await job('backfillHistory', backfillHistory);
    }
    await job('checkIllnessSuggestion', checkIllnessSuggestion);
    // The forecaster GBM is persisted, so retraining it on *every* launch is wasted
    // heat — once a day is plenty. (Sensitivity models are held in memory only, so
    // they still train each startup; their heavy lifting runs off the UI isolate.)
    await job('trainForecaster', () async {
      if (await _forecasterTrainingDue()) {
        final outcome = await trainForecaster();
        if (outcome.trained) {
          await KvStore.setString(
              _forecasterTrainStampKey, DateTime.now().toIso8601String());
        }
      }
    });
    await job('trainSensitivity', trainSensitivity);
  }

  static const _forecasterTrainStampKey = 'forecaster_last_trained_at';

  Future<bool> _forecasterTrainingDue() async {
    final raw = await KvStore.getString(_forecasterTrainStampKey);
    final last = raw == null ? null : DateTime.tryParse(raw);
    return last == null ||
        DateTime.now().difference(last) >= const Duration(hours: 20);
  }

  /// Recompute per-horizon live forecast RMSE from reconciled predictions and publish it
  /// so the prediction cone reflects recent real accuracy.
  Future<void> updateRecentForecastError() async {
    final repo = _ref.read(historyRepositoryProvider);
    final now = DateTime.now();
    final preds =
        await repo.predictions(now.subtract(const Duration(days: 14)), now);
    final pairs = [
      for (final p in preds)
        if (p.actualMgdl != null)
          (horizon: p.horizonMinutes, predicted: p.predictedMgdl, actual: p.actualMgdl!),
    ];
    if (pairs.isEmpty) return;
    _ref.read(recentHorizonErrorProvider.notifier).state =
        const UncertaintyCalibrator().perHorizonRmse(pairs);
  }

  /// Backfill historical pump data from the History Log (best-effort; no-op in dev/sim).
  Future<int> backfillHistory() async {
    final now = DateTime.now();
    final siteChanges = <DateTime>[];
    final events = <PumpEvent>[];
    final count = await HistoryBackfillService(
      _ref.read(historyRepositoryProvider),
      _ref.read(pumpClientProvider),
    ).backfill(
      from: now.subtract(const Duration(days: 14)),
      to: now,
      onDeviceChange: (kind, at) {
        if (kind == DeviceKind.site) siteChanges.add(at);
      },
      onPumpEvent: events.add,
    );
    // Record the most recent decoded site change so infusion-set age tracks the pump.
    if (siteChanges.isNotEmpty) {
      siteChanges.sort();
      await _ref
          .read(deviceStateProvider.notifier)
          .record(DeviceKind.site, at: siteChanges.last);
    }
    if (events.isNotEmpty) await PumpEventLog.append(events);
    return count;
  }

  /// Assemble per-day inputs and train the sensitivity + time-of-day models from
  /// history, pushing the results into the providers the advisor/insights read.
  Future<void> trainSensitivity() async {
    final repo = _ref.read(historyRepositoryProvider);
    final now = DateTime.now();
    final settings = _ref.read(therapySettingsProvider);
    final baseHealth =
        await repo.health(now.subtract(const Duration(days: 21)), now);

    final days = <SensitivityDayInput>[];
    for (var d = 1; d <= 21; d++) {
      final start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: d));
      final end = start.add(const Duration(days: 1));
      final lookback = start.subtract(const Duration(hours: 6));
      final cgm = await repo.cgm(lookback, end);
      if (cgm.length < 12) continue;
      final ctx = ContextBuilder.build(
        today: await repo.health(start, end),
        baseline: baseHealth,
        hasMenstrualCycle: _ref.read(userProfileProvider).hasMenstrualCycle,
      );
      if (ctx == null) continue;
      days.add(SensitivityDayInput(
        day: start,
        cgm: cgm,
        boluses: await repo.boluses(lookback, end),
        basal: await repo.basal(lookback, end),
        carbs: await repo.carbs(lookback, end),
        context: ctx,
        settings: settings,
      ));
    }
    if (days.isEmpty) return;

    // Autotune over 21 days + LOO-CV ridge fitting is CPU-bound pure Dart — run it
    // off the UI isolate and bring back just the fitted models.
    final trained = await Isolate.run(() {
      const svc = SensitivityTrainingService();
      return (profile: svc.trainTimeOfDay(days), model: svc.train(days));
    });
    final profile = trained.profile;
    if (profile != null) {
      _ref.read(timeOfDayProfileProvider.notifier).state = profile;
    }
    final model = trained.model;
    if (model != null) {
      final todayCtx = ContextBuilder.build(
        today: await repo.health(
            DateTime(now.year, now.month, now.day), now),
        baseline: baseHealth,
        hasMenstrualCycle: _ref.read(userProfileProvider).hasMenstrualCycle,
      );
      if (todayCtx != null) {
        _ref.read(sensitivityContextProvider.notifier).state =
            model.contextFor(todayCtx, trainingDays: days.length);
      }
    }
  }

  /// Run the illness detector on recent data; if it looks illness-like and the mode
  /// isn't already on, stage a suggestion for the Insights page.
  Future<void> checkIllnessSuggestion() async {
    if (_ref.read(illnessModeProvider).active) return;
    final repo = _ref.read(historyRepositoryProvider);
    final now = DateTime.now();
    final recent = await repo.cgm(now.subtract(const Duration(hours: 36)), now);
    if (recent.length < 24) return;
    final mean =
        recent.map((s) => s.mgdl).reduce((a, b) => a + b) / recent.length;
    final base = await repo.cgm(
        now.subtract(const Duration(days: 14)),
        now.subtract(const Duration(days: 2)));
    final baseMean = base.isEmpty
        ? null
        : base.map((s) => s.mgdl).reduce((a, b) => a + b) / base.length;

    final ctx = ContextBuilder.build(
      today: await repo.health(now.subtract(const Duration(hours: 36)), now),
      baseline: await repo.health(now.subtract(const Duration(days: 14)), now),
      hasMenstrualCycle: _ref.read(userProfileProvider).hasMenstrualCycle,
    );
    final s = const IllnessDetector().detect(
      meanGlucoseMgdl: mean,
      baselineGlucoseMgdl: baseMean,
      restingHr: ctx?.restingHr,
      baselineRestingHr: ctx?.baselineRestingHr,
      hrvRmssd: ctx?.overnightHrvRmssd,
      baselineHrv: ctx?.baselineHrv,
      bodyTempC: ctx?.bodyTempC,
      baselineBodyTempC: ctx?.baselineBodyTempC,
      respiratoryRate: ctx?.overnightRespiratoryRate,
      baselineRespiratoryRate: ctx?.baselineRespiratoryRate,
      spo2: ctx?.spo2,
      baselineSpo2: ctx?.baselineSpo2,
    );
    if (s.suggestActivation) {
      _ref.read(illnessSuggestionProvider.notifier).state = s;
      // Also notify (opt-out/style governed by the illnessSuggestion category), since
      // the in-app banner is easy to miss.
      try {
        await _ref.read(notificationServiceProvider).show(
              NotificationCategory.illnessSuggestion,
              'Possible illness',
              '${s.reasons.join('; ')}. Consider sick-day mode '
                  '(raises targets, adds correction).',
              bigText: true,
            );
      } catch (_) {}
    }
  }

  /// Generate and show the morning briefing on first open each morning (the reliable
  /// path; a WorkManager job covers days the app isn't opened). Idempotent per day.
  Future<void> maybeShowMorningSummary() async {
    final now = DateTime.now();
    if (now.hour < 6) return;
    final key = '${now.year}-${now.month}-${now.day}';
    if (await KvStore.getString('morning_summary_shown') == key) return;

    final day = _ref.read(dayDataProvider);
    final features = day.context;
    if (features == null || day.cgm.length < 12) return;

    // Last night specifically (23:00 yesterday → 07:00 today), not "any hour < 7"
    // across the 24h window.
    final midnight = DateTime(now.year, now.month, now.day);
    final onStart = midnight.subtract(const Duration(hours: 1));
    final onEnd = midnight.add(const Duration(hours: 7));
    final overnight = const MetricsCalculator().compute([
      for (final s in day.cgm)
        if (!s.time.isBefore(onStart) && s.time.isBefore(onEnd)) s,
    ]);
    final summary = MorningSummaryGenerator(unit: _ref.read(glucoseUnitProvider))
        .generate(
      date: now,
      overnightMetrics: overnight,
      context: features,
      sensitivity: _ref.read(effectiveSensitivityProvider),
    );
    final body = [for (final i in summary.insights.take(3)) '• ${i.detail}']
        .join('\n');
    try {
      await _ref
          .read(notificationServiceProvider)
          .showMorningSummary(summary.headline, body);
    } catch (_) {}
    await KvStore.setString('morning_summary_shown', key);
  }

  /// Compute matured meal outcomes and fold them into the learned curves.
  Future<void> runMealOutcomeLoop() async {
    final repo = _ref.read(historyRepositoryProvider);
    final res = await const MealOutcomeService().process(
      log: _ref.read(mealLogProvider),
      library: _ref.read(mealLibraryProvider),
      repo: repo,
      now: DateTime.now(),
    );
    for (final l in res.learned) {
      final cgm = await repo.cgm(
        l.outcome.eatenAt.subtract(const Duration(minutes: 30)),
        l.outcome.eatenAt.add(const Duration(hours: 3, minutes: 30)),
      );
      _ref.read(mealLibraryProvider.notifier).learnFromOutcome(l.meal, l.outcome, cgm);
    }
    await _ref.read(mealLogProvider.notifier).replaceAll(res.updatedLog);
  }

  /// Pull recent Health Connect data (sleep, HRV, resting HR, steps, workouts) into the
  /// store and refresh today's context. Returns how many samples were ingested.
  Future<int> syncHealth() async {
    final svc = _ref.read(healthSyncServiceProvider);
    final now = DateTime.now();
    final samples = await svc.fetch(now.subtract(const Duration(days: 2)), now);
    if (samples.isNotEmpty) {
      await _ref.read(historyRepositoryProvider).saveHealth(samples);
      await _ref.read(dayHistoryControllerProvider.notifier).reload();
      await refreshForecastHealthSampler();
      try {
        await checkExerciseHypoRisk(samples);
      } catch (_) {}
    }
    return samples.length;
  }

  /// After an aerobic workout, warn about the raised nocturnal-hypo risk (aerobic
  /// exercise drops glucose for hours afterwards). Gated to once per day.
  Future<void> checkExerciseHypoRisk(List<HealthSample> samples) async {
    final now = DateTime.now();
    const classifier = WorkoutClassifier();
    final aerobicToday = samples.any((s) =>
        s.type == 'exercise' &&
        s.value >= 20 && // a meaningful session
        _sameDay(s.time, now) &&
        classifier
            .classify((s.meta['activity'] as String?) ?? '')
            .raisesHypoRisk);
    if (!aerobicToday) return;

    final key = 'exercise_hypo_warned_${now.year}-${now.month}-${now.day}';
    if ((await KvStore.getBool(key)) == true) return;
    final fired = await _ref.read(notificationServiceProvider).show(
          NotificationCategory.overnightLowRisk,
          'Aerobic exercise today',
          'Aerobic exercise can keep lowering glucose for hours — watch for overnight '
              'lows and consider a slightly higher overnight target or a snack.',
        );
    if (fired) await KvStore.setBool(key, true);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Load the last few hours of stored activity into the live forecaster's sampler so
  /// its BG predictions reflect recent steps/workouts. Cheap; safe to call at startup.
  Future<void> refreshForecastHealthSampler() async {
    final now = DateTime.now();
    final recent = await _ref
        .read(historyRepositoryProvider)
        .health(now.subtract(const Duration(hours: 6)), now);
    _ref.read(forecastHealthSamplerProvider.notifier).state =
        HealthFeatureSampler(recent);
  }

  /// Retrain the residual forecaster from all stored history, recording a model-run
  /// row (registry version history) with the outcome.
  Future<TrainingOutcome> trainForecaster() async {
    final repo = _ref.read(historyRepositoryProvider);
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));
    final settings = _ref.read(therapySettingsProvider);
    final outcome = await _ref.read(forecasterModelProvider.notifier).train(
          cgm: await repo.cgm(from, now),
          boluses: await repo.boluses(from, now),
          basal: await repo.basal(from, now),
          carbs: await repo.carbs(from, now),
          settings: settings,
          annotations: await repo.annotations(from, now),
          asOf: now,
          // Feed Google Fit / Health Connect activity into the residual model.
          health: HealthFeatureSampler(await repo.health(from, now)),
        );
    if (outcome.trained) {
      try {
        await repo.saveModelRun(ModelRunRecord(
          id: now.microsecondsSinceEpoch.toString(),
          stage: outcome.promoted ? 'active' : 'candidate',
          createdAt: now,
          trainedOnDays: 30,
          metricsJson: jsonEncode({
            'baselineRmse': outcome.baselineRmse,
            'candidateRmse': outcome.candidateRmse,
            'trainSamples': outcome.trainSamples,
            'promoted': outcome.promoted,
            'reasons': outcome.reasons,
          }),
        ));
      } catch (_) {}
    }
    return outcome;
  }

  /// Quick-log a carb entry.
  Future<void> logCarb(double grams, {int absorptionMinutes = 180}) =>
      _ref.read(dayHistoryControllerProvider.notifier).logCarb(
            CarbEntry(
                time: DateTime.now(),
                grams: grams,
                absorptionMinutes: absorptionMinutes),
          );

  /// Quick-log a bolus the user actually delivered on the pump.
  Future<void> logBolus(double units) => _ref
      .read(dayHistoryControllerProvider.notifier)
      .logBolus(BolusEvent(time: DateTime.now(), units: units));

  /// Quick-log a context annotation (exercise / alcohol / stress), persisted for the
  /// retraining pipeline and surfaced on the timeline.
  Future<void> logContext(AnnotationKind kind,
      {Duration window = const Duration(hours: 2), String note = ''}) async {
    final now = DateTime.now();
    await _ref.read(historyRepositoryProvider).saveAnnotation(Annotation(
          id: '${kind.name}-${now.millisecondsSinceEpoch}',
          kind: kind,
          start: now,
          end: now.add(window),
          note: note,
        ));
    // Alcohol → a delayed-low heads-up; low alerts also tighten while the watch is active.
    if (kind == AnnotationKind.alcohol) {
      try {
        await _ref.read(notificationServiceProvider).show(
              NotificationCategory.overnightLowRisk,
              'Watch for delayed lows',
              'Alcohol can cause lows overnight and into tomorrow morning. Low alerts '
                  'will trigger earlier — consider a snack and check overnight.',
            );
      } catch (_) {}
    }
  }

  /// Confirm a queued [PendingConfirmation]: write the annotation (feeding reports and
  /// training) and, for a confirmed unannounced meal, add the carbs to history so COB and
  /// meal analysis reflect them. [kind]/[carbsGrams] override the suggested defaults when
  /// the user edits before confirming.
  Future<void> confirmPending(
    PendingConfirmation p, {
    AnnotationKind? kind,
    double? carbsGrams,
  }) async {
    // Confirming a detected illness *turns the mode on* (which boosts expected insulin
    // needs and, on deactivation, writes the annotation spanning the whole sick period) —
    // not just a one-off annotation.
    if (p.type == ConfirmationType.illness) {
      _ref.read(illnessModeProvider.notifier).activate();
      _ref.read(illnessSuggestionProvider.notifier).state = null;
      await ConfirmationDecisionStore.record(
          p.id, ConfirmationDecision.confirmed, at: DateTime.now());
      _ref.invalidate(pendingConfirmationsProvider);
      return;
    }
    final k = kind ?? p.suggestedKind;
    final grams = k.relabelsCarbs ? (carbsGrams ?? p.carbsGrams ?? 0) : 0.0;
    final repo = _ref.read(historyRepositoryProvider);
    await repo.saveAnnotation(Annotation(
      id: 'confirm-${p.id}',
      kind: k,
      start: p.start,
      end: p.end,
      carbsGrams: grams,
      confidence: 1.0, // user-confirmed → full weight
    ));
    if (k.relabelsCarbs && grams > 0) {
      await repo.saveCarb(CarbEntry(time: p.start, grams: grams));
      await _ref.read(dayHistoryControllerProvider.notifier).reload();
    }
    await ConfirmationDecisionStore.record(
        p.id, ConfirmationDecision.confirmed, at: DateTime.now());
    _ref.invalidate(pendingConfirmationsProvider);
  }

  /// Dismiss a queued item so it doesn't resurface.
  Future<void> dismissPending(PendingConfirmation p) async {
    await ConfirmationDecisionStore.record(
        p.id, ConfirmationDecision.dismissed, at: DateTime.now());
    if (p.type == ConfirmationType.illness) {
      _ref.read(illnessSuggestionProvider.notifier).state = null;
    }
    _ref.invalidate(pendingConfirmationsProvider);
  }

  /// Announce an upcoming/active exercise session: arm the raised low-alert threshold and
  /// (for aerobic) a heads-up about the raised during/after/overnight low risk.
  Future<void> announceExercise(ExercisePlan plan) async {
    _ref.read(exercisePlanProvider.notifier).state = plan;
    if (plan.type.raisesHypoRisk) {
      try {
        await _ref.read(notificationServiceProvider).show(
              NotificationCategory.overnightLowRisk,
              'Exercise mode on',
              'Low alerts will lead earlier during and after your session, and '
                  'overnight — keep fast carbs handy.',
            );
      } catch (_) {}
    }
  }

  /// Clear an announced exercise session.
  void endExercise() =>
      _ref.read(exercisePlanProvider.notifier).state = null;

  /// Record a sensor/site change and reset its age.
  Future<void> recordDeviceChange(DeviceKind kind) =>
      _ref.read(deviceStateProvider.notifier).record(kind);

  /// Notify if the sensor or site is overdue for a change.
  Future<void> checkDeviceReminders() async {
    final state = _ref.read(deviceStateProvider);
    final now = DateTime.now();
    for (final kind in DeviceKind.values) {
      if (state.isOverdue(kind, now)) {
        final age = state.age(kind, now)!;
        try {
          await _ref.read(notificationServiceProvider).show(
                NotificationCategory.deviceReminder,
                '${kind.label} is overdue',
                'It\'s been ${age.inDays}d ${age.inHours % 24}h — consider changing it.',
              );
        } catch (_) {}
      }
    }
  }

  /// Record that a saved meal was eaten now: persists the carb entry and a meal-log
  /// entry for later outcome learning.
  Future<void> logMeal({
    required SavedMeal meal,
    required int preBolusMinutes,
    required double bolusUnits,
  }) async {
    final now = DateTime.now();
    await _ref.read(dayHistoryControllerProvider.notifier).logCarb(
          CarbEntry(
            time: now,
            grams: meal.carbsGrams,
            absorptionMinutes: meal.absorptionMinutes,
          ),
        );
    await _ref.read(mealLogProvider.notifier).add(MealLogEntry(
          id: MealLogStore.newId(now),
          mealId: meal.id,
          eatenAt: now,
          carbsGrams: meal.carbsGrams,
          preBolusMinutes: preBolusMinutes,
          bolusUnits: bolusUnits,
        ));
  }
}
