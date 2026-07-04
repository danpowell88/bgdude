/// Training harness that turns per-day history into learned sensitivity models.
///
/// This is the glue a nightly job runs: for each day of the user's history it runs
/// the Autotune-style per-day estimator (`autotune.dart`) to produce a *sensitivity
/// deviation* label, pairs it with that day's contextual features (sleep, HRV, …),
/// and fits the [SensitivityModel]. A parallel wrapper drives the
/// [TimeOfDaySensitivityAnalyzer] over the same history to learn a
/// [TimeOfDayProfile]. Everything here only ever *learns* — it never writes to the
/// pump; downstream code reads the returned models to produce suggestions.
library;

import '../analytics/therapy_settings.dart';
import '../core/samples.dart';
import 'autotune.dart';
import 'sensitivity_model.dart';
import 'time_of_day_sensitivity.dart';

/// One historical day's inputs: the CGM/insulin/carb slice plus the contextual
/// features and therapy settings that were in force that day.
///
/// [basal] and [boluses] may extend up to one DIA before [day]'s midnight so IOB is
/// accurate at the start of the day; only same-day CGM steps are scored downstream.
class SensitivityDayInput {
  const SensitivityDayInput({
    required this.day,
    required this.cgm,
    required this.boluses,
    required this.basal,
    required this.carbs,
    required this.context,
    required this.settings,
  });

  final DateTime day;
  final List<CgmSample> cgm;
  final List<BolusEvent> boluses;
  final List<BasalSegment> basal;
  final List<CarbEntry> carbs;

  /// That day's contextual features (sleep, HRV, resting HR, …).
  final ContextFeatures context;

  /// Therapy settings in force that day (ISF/CR/target/basal by segment).
  final TherapySettings settings;
}

/// Builds training examples and fits sensitivity models from per-day history.
class SensitivityTrainingService {
  const SensitivityTrainingService({
    this.minDays = 14,
    this.minCarbFreeMinutes = 120,
  });

  /// Fewer than this many *usable* examples => we don't trust a learned model.
  final int minDays;

  /// A day needs at least this much carb-free observation time for its Autotune
  /// label to be meaningful; days below the floor are skipped.
  final int minCarbFreeMinutes;

  /// Run Autotune over each day and turn the qualifying days into training
  /// examples. Days without enough carb-free observation time are skipped, since
  /// their sensitivity estimate is dominated by carb noise.
  List<SensitivityExample> buildExamples(List<SensitivityDayInput> days) {
    final tuner = Autotune();
    final examples = <SensitivityExample>[];
    for (final d in days) {
      final result = tuner.analyseDay(
        day: d.day,
        cgm: d.cgm,
        boluses: d.boluses,
        basal: d.basal,
        carbs: d.carbs,
        settings: d.settings,
      );
      if (result.carbFreeMinutes < minCarbFreeMinutes) continue;
      examples.add(SensitivityExample(
        features: d.context,
        sensitivityDeviation: result.sensitivityMultiplier,
        weight: result.confidence.clamp(0.1, 1.0),
      ));
    }
    return examples;
  }

  /// Fit a [SensitivityModel] from history. Returns null when there aren't enough
  /// usable days, or when the model itself declined to train (its own
  /// `minExamples` floor). A returned model is guaranteed `isTrained`.
  SensitivityModel? train(List<SensitivityDayInput> days) {
    final examples = buildExamples(days);
    if (examples.length < minDays) return null;
    final model = SensitivityModel();
    model.train(examples);
    return model.isTrained ? model : null;
  }

  /// Learn a [TimeOfDayProfile] from the same per-day history by driving the
  /// existing [TimeOfDaySensitivityAnalyzer]. Returns null when there are fewer
  /// than the analyzer's `minDays` of history (below which it can only produce a
  /// neutral profile).
  ///
  /// [settings] defaults to the first day's therapy settings; pass one explicitly
  /// if the profile should be scored against a specific IDP.
  TimeOfDayProfile? trainTimeOfDay(
    List<SensitivityDayInput> days, {
    TherapySettings? settings,
    TimeOfDaySensitivityAnalyzer? analyzer,
  }) {
    if (days.isEmpty) return null;
    final tod = analyzer ?? TimeOfDaySensitivityAnalyzer();
    if (days.length < tod.minDays) return null;
    final resolved = settings ?? days.first.settings;
    final histories = [
      for (final d in days)
        DayHistory(
          day: d.day,
          cgm: d.cgm,
          boluses: d.boluses,
          basal: d.basal,
          carbs: d.carbs,
        ),
    ];
    return tod.learn(days: histories, settings: resolved);
  }
}
