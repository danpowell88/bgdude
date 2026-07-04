/// Care-safety detectors: pattern alarms that fire on a live snapshot rather than
/// on historical review. Both are *pure* functions of the passed-in data (no clock,
/// no I/O) so they are trivially unit-testable and can be re-run cheaply on every
/// pump/CGM snapshot by the app's AlertService.
///
///   * [MissedBolusDetector] — you ate and forgot to bolus: a sustained unexplained
///     glucose rise with no bolus and no carb entry near it.
///   * [StubbornHighDetector] — glucose stuck high with insulin on board but not
///     coming down, which can indicate an infusion-site failure.
///
/// These reuse the existing [MealDetector], [IobCalculator] and [TherapySettings]
/// engines verbatim; they add only the "should we warn the user?" decision layer.
library;

import '../analytics/insulin_math.dart';
import '../analytics/therapy_settings.dart';
import '../core/samples.dart';
import '../core/units.dart';
import '../ml/event_detectors.dart';

/// Raised when a probable meal (rise) happened with no matching bolus or carb entry.
class MissedBolusAlert {
  const MissedBolusAlert({
    required this.mealTime,
    required this.estimatedCarbsGrams,
    required this.riseRateMgdlPerMin,
    required this.confidence,
  });

  /// Approximate time the unannounced meal started (the rise onset).
  final DateTime mealTime;

  /// Model-estimated carbohydrate load of the unannounced meal, grams.
  final double estimatedCarbsGrams;

  /// Peak unexplained rise rate that triggered the candidate, mg/dL per minute.
  final double riseRateMgdlPerMin;

  /// 0..1 confidence carried through from the meal detector.
  final double confidence;
}

/// Flags a sustained unexplained glucose rise that has NO bolus and NO carb entry
/// near it — i.e. the classic "ate and forgot to bolus" pattern.
///
/// The heavy lifting (is this actually a meal-shaped rise, and how big?) is delegated
/// to [MealDetector]; this class only adds the "was it covered?" test.
class MissedBolusDetector {
  const MissedBolusDetector({
    this.lookbackMinutes = 120,
    this.bolusWindowMinutes = 25,
    this.minEstimatedCarbs = 15,
  });

  /// How far back from [detect]'s `now` to consider meal candidates.
  final int lookbackMinutes;

  /// A bolus or carb entry within +/- this many minutes of the meal counts as
  /// "covered" and suppresses the alert.
  final int bolusWindowMinutes;

  /// Ignore piddly rises; only meaningful meals are worth nagging about.
  final double minEstimatedCarbs;

  MissedBolusAlert? detect({
    required List<CgmSample> cgm,
    required List<BolusEvent> boluses,
    required List<CarbEntry> carbs,
    required List<BasalSegment> basal,
    required TherapySettings settings,
    required DateTime now,
  }) {
    // Use a meal detector whose sustain window is long enough that a single
    // real meal is captured as one candidate (rather than fragmented), so the
    // per-candidate carb estimate is comparable to `minEstimatedCarbs`.
    final mealDetector = MealDetector(
      insulinModel: InsulinModel(
        durationMinutes: settings.durationOfInsulinActionMinutes,
        peakMinutes: settings.insulinPeakMinutes,
      ),
      sustainMinutes: 45,
    );

    final candidates = mealDetector.detect(
      cgm: cgm,
      boluses: boluses,
      basal: basal,
      settings: settings,
    );

    final lookbackStart = now.subtract(Duration(minutes: lookbackMinutes));

    // Most-recent-first, so we prefer the freshest qualifying candidate.
    final recent = [
      for (final c in candidates)
        if (!c.time.isBefore(lookbackStart) &&
            !c.time.isAfter(now) &&
            c.estimatedCarbsGrams >= minEstimatedCarbs)
          c,
    ]..sort((a, b) => b.time.compareTo(a.time));

    final window = Duration(minutes: bolusWindowMinutes);
    for (final c in recent) {
      final coveredByBolus = boluses.any((b) =>
          b.units > 0 && (b.time.difference(c.time)).abs() <= window);
      final coveredByCarbs =
          carbs.any((e) => (e.time.difference(c.time)).abs() <= window);
      if (!coveredByBolus && !coveredByCarbs) {
        return MissedBolusAlert(
          mealTime: c.time,
          estimatedCarbsGrams: c.estimatedCarbsGrams,
          riseRateMgdlPerMin: c.riseRateMgdlPerMin,
          confidence: c.confidence,
        );
      }
    }
    return null;
  }
}

/// Raised when glucose has been stuck high with active insulin but is not falling.
class StubbornHighAlert {
  const StubbornHighAlert({
    required this.since,
    required this.mgdl,
    required this.iobUnits,
    required this.siteAgeHours,
    required this.likelySiteIssue,
  });

  /// When the continuous-high run started.
  final DateTime since;

  /// Latest glucose reading, mg/dL.
  final double mgdl;

  /// Insulin on board at `now`, units.
  final double iobUnits;

  /// Age of the current infusion site in hours, if known.
  final double? siteAgeHours;

  /// True when the site is old enough (>48h) that occlusion / absorption failure
  /// is a plausible cause of the un-budging high.
  final bool likelySiteIssue;
}

/// Detects a glucose value stuck above [GlucoseThresholds.high] for a sustained span,
/// with meaningful IOB, that is flat-or-rising (not meaningfully falling). This is the
/// signature of insulin that isn't working — commonly a failed/occluded infusion site.
class StubbornHighDetector {
  const StubbornHighDetector({
    this.minMinutesHigh = 120,
    this.notFallingRocMgdlPerMin = -0.3,
    this.minIobUnits = 0.5,
    this.rocWindowMinutes = 30,
    this.maxGapMinutes = 15,
    this.siteIssueAgeHours = 48,
  });

  /// Glucose must have been continuously high for at least this long.
  final int minMinutesHigh;

  /// Recent rate-of-change must be >= this (flat or rising). A value like -0.3
  /// tolerates a trivial drift while still catching "not really coming down".
  final double notFallingRocMgdlPerMin;

  /// IOB must exceed this for the "insulin isn't working" story to hold.
  final double minIobUnits;

  /// Window over which the recent rate-of-change is measured.
  final int rocWindowMinutes;

  /// A gap larger than this breaks the continuous-high run (sensor dropout etc.).
  final int maxGapMinutes;

  /// Site age beyond which a stubborn high is flagged as a likely site issue.
  final double siteIssueAgeHours;

  StubbornHighAlert? detect({
    required List<CgmSample> cgm,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required TherapySettings settings,
    double? siteAgeHours,
    required DateTime now,
  }) {
    final sorted = [...cgm]
      ..removeWhere((s) => s.sensorWarmup || s.mgdl <= 0 || s.time.isAfter(now))
      ..sort((a, b) => a.time.compareTo(b.time));
    if (sorted.length < 2) return null;

    final latest = sorted.last;
    if (latest.mgdl <= GlucoseThresholds.high) return null;

    // Walk backwards from the latest sample collecting the contiguous run where
    // glucose stays above the high threshold (no gap larger than maxGapMinutes).
    var runStartIndex = sorted.length - 1;
    for (var i = sorted.length - 1; i >= 0; i--) {
      if (sorted[i].mgdl <= GlucoseThresholds.high) break;
      if (i < sorted.length - 1) {
        final gap = sorted[i + 1].time.difference(sorted[i].time).inMinutes;
        if (gap > maxGapMinutes) break;
      }
      runStartIndex = i;
    }
    final since = sorted[runStartIndex].time;
    final runMinutes = latest.time.difference(since).inMinutes;
    if (runMinutes < minMinutesHigh) return null;

    // Recent rate-of-change over the last rocWindowMinutes of the run.
    final rocStart = latest.time.subtract(Duration(minutes: rocWindowMinutes));
    final window = [
      for (final s in sorted)
        if (!s.time.isBefore(rocStart)) s,
    ];
    if (window.length < 2) return null;
    final first = window.first;
    final spanMin = latest.time.difference(first.time).inMinutes;
    if (spanMin <= 0) return null;
    final roc = (latest.mgdl - first.mgdl) / spanMin;
    if (roc < notFallingRocMgdlPerMin) return null; // meaningfully falling → fine

    final iob = IobCalculator(
      model: InsulinModel(
        durationMinutes: settings.durationOfInsulinActionMinutes,
        peakMinutes: settings.insulinPeakMinutes,
      ),
    ).total(boluses, basal, now).units;
    if (iob <= minIobUnits) return null;

    return StubbornHighAlert(
      since: since,
      mgdl: latest.mgdl,
      iobUnits: iob,
      siteAgeHours: siteAgeHours,
      likelySiteIssue: siteAgeHours != null && siteAgeHours > siteIssueAgeHours,
    );
  }
}
