/// Riverpod providers that wire the layers together and expose app state to the UI.
/// Kept hand-written (not codegen) so the wiring is readable at a glance.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../insights/a1c_goal.dart';
import '../insights/alcohol_watch.dart';
import '../insights/alert_monitor.dart';
import '../insights/care_detectors.dart';
import '../insights/daily_narrative.dart';
import '../insights/illness_mode.dart';
import '../insights/sleep_insight.dart';
import '../insights/morning_summary.dart';
import '../insights/notification_prefs.dart';
import '../insights/notifications.dart';
import '../insights/post_meal_movement.dart';
import '../insights/workout_classifier.dart';
import '../integrations/nightscout.dart';
import '../logging/device_changes.dart';
import '../data/health_sync.dart';
import '../data/history_repository.dart';
import '../data/kv_store.dart';
import '../dev/sim_data.dart';
import '../meals/meal_library.dart';
import '../meals/meal_log.dart';
import '../meals/meal_outcome_service.dart';
import '../meals/prebolus_coach.dart';
import '../ml/basal_recommender.dart';
import '../ml/forecast_features.dart';
import '../ml/forecaster.dart';
import '../ml/forecaster_service.dart';
import '../ml/health_features.dart';
import '../ml/sensitivity_model.dart';
import '../ml/sensitivity_training.dart';
import '../ml/time_of_day_sensitivity.dart';
import '../ml/uncertainty_calibrator.dart';
import '../pump/history_backfill.dart';
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

class NotificationPrefsNotifier extends StateNotifier<NotificationPrefs> {
  NotificationPrefsNotifier() : super(NotificationPrefs.defaults()) {
    _restore();
  }
  static const _key = 'notification_prefs_v1';

  Future<void> _restore() async {
    final raw = await KvStore.getString(_key);
    if (raw != null) {
      state = NotificationPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  Future<void> setCategory(NotificationCategory c, CategoryPref pref) async {
    state = state.withCategory(c, pref);
    await KvStore.setString(_key, jsonEncode(state.toJson()));
  }
}

/// Display unit (mmol/L default for the AU user).
final glucoseUnitProvider = StateProvider<GlucoseUnit>((ref) => GlucoseUnit.mmol);

/// Whether first-run onboarding (pairing warning + permission grants) is complete.
/// Initialized from shared_preferences in main(); flipping it persists the flag.
final onboardingDoneProvider = StateProvider<bool>((ref) => false);

/// Whether advanced mode (model internals, prediction decomposition) is enabled.
final advancedModeProvider = StateProvider<bool>((ref) => false);

/// Dev mode: run against the in-app t:slim + CGM simulator instead of the native
/// pump bridge, so the whole app is usable without hardware. Persisted in main().
final devModeProvider = StateProvider<bool>((ref) => false);

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

/// The user's therapy settings (their pump IDP: basal schedule, ISF, CR, targets),
/// persisted. Feeds the what-if engine, bolus advisor, and predictions.
final therapySettingsProvider =
    StateNotifierProvider<TherapyNotifier, TherapySettings>(
        (ref) => TherapyNotifier());

class TherapyNotifier extends StateNotifier<TherapySettings> {
  TherapyNotifier() : super(TherapySettings.placeholder()) {
    _restore();
  }
  static const _key = 'therapy_settings_v1';

  Future<void> _restore() async {
    final raw = await KvStore.getString(_key);
    if (raw != null) {
      state = TherapySettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  Future<void> save(TherapySettings settings) async {
    state = settings;
    await KvStore.setString(_key, jsonEncode(settings.toJson()));
  }
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

class A1cTargetNotifier extends StateNotifier<double> {
  A1cTargetNotifier() : super(6.5) {
    _restore();
  }
  static const _key = 'a1c_target_gmi';
  Future<void> _restore() async {
    final v = await KvStore.getDouble(_key);
    if (v != null) state = v;
  }

  Future<void> save(double gmiPercent) async {
    state = gmiPercent;
    await KvStore.setDouble(_key, gmiPercent);
  }
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
  final iob =
      const IobCalculator().total(state.boluses, state.basal, state.now).units;
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
  final repo = ref.read(historyRepositoryProvider);
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
  final repo = ref.read(historyRepositoryProvider);
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
      .read(historyRepositoryProvider)
      .health(range.from, range.to);
  return const PostMealMovementAnalyzer().analyze(meals: meals, steps: steps);
});

/// Therapy report (learned daily sensitivity trend via Autotune) for the range.
final therapyReportProvider = FutureProvider<TherapyReport>((ref) async {
  final range = ref.watch(reportRangeProvider);
  final repo = ref.read(historyRepositoryProvider);
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
  final repo = ref.read(historyRepositoryProvider);
  return const CorrelationReportBuilder().build(
    cgm: await repo.cgm(range.from, range.to),
    health: await repo.health(range.from, range.to),
    range: range,
    now: DateTime.now(),
  );
});

/// Menstrual-cycle glucose comparison (follicular vs luteal) for the range.
final cycleReportProvider = FutureProvider<CycleReport>((ref) async {
  final range = ref.watch(reportRangeProvider);
  final repo = ref.read(historyRepositoryProvider);
  return const CycleReportBuilder().build(
    cgm: await repo.cgm(range.from, range.to),
    health: await repo.health(range.from, range.to),
    range: range,
    now: DateTime.now(),
  );
});

/// Model-performance report: forecast accuracy, Clarke zones, interval calibration.
final modelReportProvider = FutureProvider<ModelReport>((ref) async {
  final range = ref.watch(reportRangeProvider);
  final repo = ref.read(historyRepositoryProvider);
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
  final repo = ref.read(historyRepositoryProvider);
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

/// A pending illness-mode suggestion from the detector (null when none). Surfaced as a
/// banner on the Insights page.
final illnessSuggestionProvider =
    StateProvider<IllnessSuggestion?>((ref) => null);

/// The Confirmation Inbox: detected-but-unconfirmed events (unannounced meals,
/// compression lows, illness) over recent history, minus anything already decided or
/// annotated. Confirming/dismissing goes through [AppJobs.confirmPending]/[dismissPending].
final pendingConfirmationsProvider =
    FutureProvider<List<PendingConfirmation>>((ref) async {
  final repo = ref.read(historyRepositoryProvider);
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
  return illness.overlay(ctx);
});

/// The encrypted history repository. Overridden in main() with a SQLCipher-backed
/// [DriftHistoryRepository]; defaults to in-memory so tests and DB-less contexts work.
final historyRepositoryProvider =
    Provider<HistoryRepository>((ref) => InMemoryHistoryRepository());

/// Health Connect ingestion service.
final healthSyncServiceProvider =
    Provider<HealthSyncService>((ref) => HealthSyncService());

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

  return PredictionState(
    now: latest.time,
    currentMgdl: latest.mgdl,
    recentRocMgdlPerMin: roc,
    boluses: day.boluses,
    basal: day.basal,
    carbs: day.carbs,
    settings: day.settings,
    context: ref.watch(effectiveSensitivityProvider),
    healthFeatures:
        healthSampler?.featuresAt(latest.time) ?? HealthFeatureSampler.zeros,
  );
});

/// Saved-meal library with shared_preferences persistence (the drift `SavedMeals`
/// table is the eventual home once the encrypted DB is wired through the app).
final mealLibraryProvider =
    StateNotifierProvider<MealLibraryNotifier, MealLibrary>(
        (ref) => MealLibraryNotifier());

class MealLibraryNotifier extends StateNotifier<MealLibrary> {
  MealLibraryNotifier() : super(MealLibrary()) {
    _restore();
  }

  static const _prefsKey = 'meal_library_v1';

  Future<void> _restore() async {
    final raw = await KvStore.getStringList(_prefsKey);
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

class NightscoutConfigNotifier extends StateNotifier<NightscoutConfig> {
  NightscoutConfigNotifier() : super(const NightscoutConfig()) {
    _restore();
  }
  static const _key = 'nightscout_config_v1';

  Future<void> _restore() async {
    final raw = await KvStore.getString(_key);
    if (raw != null) {
      state = NightscoutConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  Future<void> save(NightscoutConfig config) async {
    state = config;
    await KvStore.setString(_key, jsonEncode(config.toJson()));
  }
}

final nightscoutClientProvider = Provider<NightscoutClient>(
    (ref) => NightscoutClient(ref.watch(nightscoutConfigProvider)));

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
  bool _shouldFire(NotificationCategory c, DateTime now) {
    final pref = _ref.read(notificationPrefsProvider).of(c);
    if (!pref.enabled) return false;
    final interval =
        Duration(minutes: pref.repeatMinutes > 0 ? pref.repeatMinutes : 30);
    final last = _lastFired[c];
    if (last != null && now.difference(last) < interval) return false;
    _lastFired[c] = now;
    return true;
  }

  static NotificationCategory _categoryFor(GlucoseAlertKind k) => switch (k) {
        GlucoseAlertKind.urgentLow => NotificationCategory.urgentLow,
        GlucoseAlertKind.predictedLow => NotificationCategory.predictedLow,
        GlucoseAlertKind.predictedHigh => NotificationCategory.predictedHigh,
      };

  Future<void> onSnapshot() async {
    // Pump-status alerts (alarms + low reservoir) come straight off the snapshot and
    // don't depend on a CGM/prediction being available, so check them first.
    await _checkPumpStatus();

    final state = _ref.read(livePredictionStateProvider);
    if (state == null) return;
    final forecasts = const UncertaintyCalibrator().calibrateAll(
      _ref.read(forecasterProvider).forecastState(state),
      _ref.read(recentHorizonErrorProvider),
    );
    final now = DateTime.now();

    // Alcohol raises the low-alert threshold (earlier warning) while its watch is active.
    const alcohol = AlcoholWatch();
    final recentAnnotations = await _ref
        .read(historyRepositoryProvider)
        .annotations(now.subtract(alcohol.window), now);
    final lowMgdl =
        alcohol.activeAt(recentAnnotations, now) ? alcohol.raisedLowMgdl : 70.0;

    // Evaluate without an internal cooldown — repeat/opt-out is governed by prefs here.
    final alert = AlertMonitor(cooldown: Duration.zero, lowMgdl: lowMgdl).evaluate(
      forecasts: forecasts,
      currentMgdl: state.currentMgdl,
      now: now,
      lastFired: const {},
      unit: _ref.read(glucoseUnitProvider),
    );
    if (alert != null) {
      final category = _categoryFor(alert.kind);
      if (_shouldFire(category, now)) {
        try {
          await _ref
              .read(notificationServiceProvider)
              .show(category, alert.title, alert.body);
        } catch (_) {}
      }
    }

    // Post-meal "walk it off": a spike predicted soon after a meal, and not already
    // moving → suggest a short walk (a short post-meal walk blunts the spike).
    final dayForMeal = _ref.read(dayDataProvider);
    final ateRecently = dayForMeal.carbs.any((c) =>
        !c.time.isAfter(now) && now.difference(c.time) <= const Duration(minutes: 45));
    final peak = forecasts.isEmpty
        ? state.currentMgdl
        : forecasts.map((f) => f.mgdl).reduce((a, b) => a > b ? a : b);
    final activity =
        _ref.read(forecastHealthSamplerProvider)?.featuresAt(now).first ?? 0.0;
    if (const PostMealMovementCoach().shouldNudge(
          ateWithinWindow: ateRecently,
          currentMgdl: state.currentMgdl,
          forecastPeakMgdl: peak,
          recentStepsPerMin: activity * 100, // activity feature ≈ steps/min ÷ 100
        ) &&
        _shouldFire(NotificationCategory.postMealMovement, now)) {
      try {
        await _ref.read(notificationServiceProvider).show(
              NotificationCategory.postMealMovement,
              'A short walk would help',
              'A post-meal rise is on the way — even 10 minutes of walking now will '
                  'blunt the spike.',
            );
      } catch (_) {}
    }

    // Rescue carbs: fire the act-now case (urgent) as its own category so it can be
    // tuned/opted separately from the predictive low alert above.
    final rescue = _ref.read(rescueCarbAdviceProvider);
    if (rescue != null &&
        rescue.urgent &&
        _shouldFire(NotificationCategory.rescueCarb, now)) {
      try {
        await _ref.read(notificationServiceProvider).show(
              NotificationCategory.rescueCarb,
              'Take rescue carbs',
              '~${rescue.grams.round()}g fast carbs now — ${rescue.reason}',
            );
      } catch (_) {}
    }

    // Care alerts: missed bolus and stubborn-high (possible site failure).
    final day = _ref.read(dayDataProvider);
    final missed = const MissedBolusDetector().detect(
      cgm: day.cgm,
      boluses: day.boluses,
      carbs: day.carbs,
      basal: day.basal,
      settings: day.settings,
      now: now,
    );
    if (missed != null && _shouldFire(NotificationCategory.missedBolus, now)) {
      try {
        await _ref.read(notificationServiceProvider).show(
              NotificationCategory.missedBolus,
              'Missed bolus?',
              'A ~${missed.estimatedCarbsGrams.round()}g rise with no bolus logged — '
                  'correct now if you ate.',
            );
      } catch (_) {}
    }

    final siteMin = _ref.read(deviceStateProvider).age(DeviceKind.site, now)?.inMinutes;
    final stubborn = const StubbornHighDetector().detect(
      cgm: day.cgm,
      boluses: day.boluses,
      basal: day.basal,
      settings: day.settings,
      siteAgeHours: siteMin == null ? null : siteMin / 60.0,
      now: now,
    );
    if (stubborn != null && _shouldFire(NotificationCategory.stubbornHigh, now)) {
      try {
        await _ref.read(notificationServiceProvider).show(
              NotificationCategory.stubbornHigh,
              'Stubborn high',
              stubborn.likelySiteIssue
                  ? 'High for a while with insulin doing little, and your site is '
                      '~${(stubborn.siteAgeHours! / 24).toStringAsFixed(1)} days old — '
                      'consider a set change.'
                  : 'High for a while with IOB not bringing it down — watch for a '
                      'possible site issue.',
            );
      } catch (_) {}
    }

    // Log predictions (throttled) so the model-accuracy view can score them later.
    if (_lastPredictionLog == null ||
        now.difference(_lastPredictionLog!).inMinutes >= 5) {
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
        } catch (_) {}
      }
    }
  }

  /// Below this many units left, warn about the reservoir.
  static const double _reservoirLowUnits = 15.0;
  String? _lastAlarmSignature;

  /// Surface active pump alarms and a low reservoir from the latest snapshot.
  Future<void> _checkPumpStatus() async {
    final snap = _ref.read(pumpSnapshotProvider).valueOrNull;
    if (snap == null) return;
    final now = DateTime.now();

    // Active alarms/alerts on the pump. Fire when the active set changes (so a new alarm
    // notifies) and re-alert per the category's repeat interval while it persists.
    final active = [...snap.activeAlarms, ...snap.activeAlerts];
    final signature = active.join('|');
    if (active.isNotEmpty) {
      final changed = signature != _lastAlarmSignature;
      if ((changed || _shouldFire(NotificationCategory.pumpAlarm, now))) {
        _lastAlarmSignature = signature;
        try {
          await _ref.read(notificationServiceProvider).show(
                NotificationCategory.pumpAlarm,
                snap.activeAlarms.isNotEmpty ? 'Pump alarm' : 'Pump alert',
                '${active.map(_humanizeAlarm).join(', ')} — check your pump.',
              );
        } catch (_) {}
      }
    } else {
      _lastAlarmSignature = null;
    }

    final reservoir = snap.reservoirUnits;
    if (reservoir != null &&
        reservoir <= _reservoirLowUnits &&
        _shouldFire(NotificationCategory.reservoirLow, now)) {
      try {
        await _ref.read(notificationServiceProvider).show(
              NotificationCategory.reservoirLow,
              'Low reservoir',
              '~${reservoir.round()} U left — plan a cartridge change soon.',
            );
      } catch (_) {}
    }
  }

  /// Turn a pumpx2 enum-ish alarm name (e.g. "LOW_INSULIN_ALARM") into readable text.
  static String _humanizeAlarm(String raw) {
    final words = raw
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return raw;
    return words.first[0].toUpperCase() + words.first.substring(1) +
        (words.length > 1 ? ' ${words.sublist(1).join(' ')}' : '');
  }
}

/// Background jobs run at startup (and on demand): close the meal-outcome loop,
/// reconcile matured predictions, and retrain the forecaster when enough data exists.
final appJobsProvider = Provider<AppJobs>((ref) => AppJobs(ref));

class AppJobs {
  AppJobs(this._ref);
  final Ref _ref;

  Future<void> runStartup() async {
    if (!_ref.read(devModeProvider)) {
      try {
        await syncHealth();
      } catch (_) {}
    }
    try {
      await refreshForecastHealthSampler();
    } catch (_) {}
    try {
      await runMealOutcomeLoop();
    } catch (_) {}
    try {
      await _ref.read(historyRepositoryProvider).reconcilePredictions(DateTime.now());
      await updateRecentForecastError();
    } catch (_) {}
    try {
      await maybeShowMorningSummary();
    } catch (_) {}
    try {
      await checkDeviceReminders();
    } catch (_) {}
    if (!_ref.read(devModeProvider)) {
      try {
        await backfillHistory();
      } catch (_) {}
    }
    try {
      await checkIllnessSuggestion();
    } catch (_) {}
    try {
      await trainForecaster();
    } catch (_) {}
    try {
      await trainSensitivity();
    } catch (_) {}
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
    final count =
        await HistoryBackfillService(_ref.read(historyRepositoryProvider)).backfill(
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

    const svc = SensitivityTrainingService();
    final profile = svc.trainTimeOfDay(days);
    if (profile != null) {
      _ref.read(timeOfDayProfileProvider.notifier).state = profile;
    }
    final model = svc.train(days);
    if (model != null) {
      final todayCtx = ContextBuilder.build(
        today: await repo.health(
            DateTime(now.year, now.month, now.day), now),
        baseline: baseHealth,
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
    if (p.type == ConfirmationType.illness) {
      _ref.read(illnessSuggestionProvider.notifier).state = null;
    }
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
