/// Riverpod providers that wire the layers together and expose app state to the UI.
/// Kept hand-written (not codegen) so the wiring is readable at a glance.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/bolus_advisor.dart';
import '../analytics/predictor.dart';
import '../analytics/therapy_settings.dart';
import '../core/samples.dart';
import '../core/units.dart';
import '../feedback/annotations.dart';
import '../insights/illness_mode.dart';
import '../insights/notifications.dart';
import '../dev/sim_data.dart';
import '../meals/meal_library.dart';
import '../meals/prebolus_coach.dart';
import '../ml/forecaster.dart';
import '../ml/sensitivity_model.dart';
import '../ml/time_of_day_sensitivity.dart';
import '../pump/pump_client.dart';
import '../pump/pump_snapshot.dart';
import '../pump/pump_source.dart';
import '../pump/simulated_pump_client.dart';
import '../timeline/day_event.dart';
import '../timeline/event_builder.dart';
import '../widget/home_widget_service.dart';
import 'day_data.dart';

export 'day_data.dart';

/// Notification service (overridden in main() with the initialised instance).
final notificationServiceProvider =
    Provider<NotificationService>((ref) => throw UnimplementedError());

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

/// The user's therapy settings (imported from the pump IDP during onboarding).
final therapySettingsProvider =
    StateProvider<TherapySettings>((ref) => TherapySettings.placeholder());

/// Today's sensitivity context (from the sensitivity model; neutral until trained).
final sensitivityContextProvider =
    StateProvider<SensitivityContext>((ref) => SensitivityContext.neutral);

/// Shared engines.
final predictorProvider = Provider<GlucosePredictor>((ref) => GlucosePredictor());
final forecasterProvider = Provider<Forecaster>((ref) => Forecaster());
final bolusAdvisorProvider = Provider<BolusAdvisor>(
    (ref) => BolusAdvisor(predictor: ref.watch(predictorProvider)));
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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      _controller.mode = IllnessMode.decode(raw);
      state = _controller.mode;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _controller.mode.encode());
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

/// The day's data (history + events + context). Simulated in dev mode; assembled
/// from live data otherwise. Watch this for anything that needs history.
final dayDataProvider = Provider<DayData>((ref) {
  final settings = ref.watch(therapySettingsProvider);
  final sim = ref.watch(simulatedDayProvider);
  if (sim != null) {
    return DayData(
      start: sim.start,
      end: sim.end,
      cgm: sim.cgm,
      boluses: sim.boluses,
      basal: sim.basal,
      carbs: sim.carbs,
      settings: sim.settings,
      context: sim.context,
      isSimulated: true,
    );
  }
  // Real mode: history repositories land with the drift wiring; for now expose the
  // single live reading so the current-value UI works.
  final snap = ref.watch(pumpSnapshotProvider).valueOrNull;
  final live = snap?.toCgmSample();
  return DayData(
    start: live?.time ?? DateTime.now(),
    end: live?.time ?? DateTime.now(),
    cgm: live == null ? const [] : [live],
    boluses: const [],
    basal: const [],
    carbs: const [],
    settings: settings,
    context: null,
    isSimulated: false,
  );
});

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
/// lows) with any user tags applied. This is the timeline's single source.
final dayEventsProvider = Provider<List<DayEvent>>((ref) {
  final day = ref.watch(dayDataProvider);
  final unit = ref.watch(glucoseUnitProvider);
  final overrides = ref.watch(eventDispositionProvider);

  final events = EventBuilder(unit: unit).build(day);
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

  return PredictionState(
    now: latest.time,
    currentMgdl: latest.mgdl,
    recentRocMgdlPerMin: roc,
    boluses: day.boluses,
    basal: day.basal,
    carbs: day.carbs,
    settings: day.settings,
    context: ref.watch(effectiveSensitivityProvider),
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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
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
