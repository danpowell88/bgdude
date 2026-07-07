/// Scans recent history for detected-but-unconfirmed events and turns them into
/// [PendingConfirmation]s for the Confirmation Inbox. Pure and testable: it takes the raw
/// series + prior decisions + existing annotations and returns the queue, excluding
/// anything already decided or already annotated.
library;

import '../analytics/therapy_settings.dart';
import '../core/samples.dart';
import '../insights/care_detectors.dart';
import '../insights/illness_mode.dart';
import '../ml/event_detectors.dart';
import 'annotations.dart';
import 'pending_confirmation.dart';
import '../core/sleep_window.dart';

class ConfirmationService {
  const ConfirmationService({
    this.minConfidence = 0.3,
    this.carbLogWindow = const Duration(minutes: 20),
  });

  /// Below this detector confidence, candidates are not surfaced.
  final double minConfidence;

  /// A meal candidate is treated as *announced* (and skipped) if a carb entry exists
  /// within this window of it.
  final Duration carbLogWindow;

  List<PendingConfirmation> scan({
    required DateTime now,
    required List<CgmSample> cgm,
    required List<BolusEvent> boluses,
    required List<BasalSegment> basal,
    required List<CarbEntry> carbs,
    required TherapySettings settings,
    required List<Annotation> annotations,
    required Set<String> decidedIds,
    bool Function(DateTime)? isAsleep,
    IllnessSuggestion? illness,
    double? siteAgeHours,
  }) {
    final asleep = isAsleep ?? defaultAsleepAt;
    final out = <PendingConfirmation>[];

    // 1. Unannounced meals: unexplained rises with no carbs logged near them.
    final meals = MealDetector().detect(
      cgm: cgm,
      boluses: boluses,
      basal: basal,
      settings: settings,
    );
    for (final m in meals) {
      if (m.confidence < minConfidence) continue;
      // Announced = a carb entry OR a bolus near the rise (TASK-171): a normal
      // pump-bolused meal whose carbs were never logged in-app must not nag as
      // an unannounced meal — that false positive drives alarm fatigue and bad
      // training annotations. (Auto microboluses don't count as announcements.)
      final announced = carbs.any((c) =>
              (c.time.difference(m.time)).abs() <= carbLogWindow) ||
          boluses.any((b) =>
              !b.isAutomatic &&
              b.units > 0 &&
              (b.time.difference(m.time)).abs() <= carbLogWindow);
      if (announced) continue;
      if (_coveredBy(annotations, m.time,
          const {AnnotationKind.missedCarbs, AnnotationKind.extraCarbs})) {
        continue;
      }
      out.add(PendingConfirmation(
        type: ConfirmationType.unannouncedMeal,
        start: m.time,
        end: m.time.add(const Duration(minutes: 30)),
        title: 'Unannounced meal?',
        detail:
            'A rise of ~${m.estimatedCarbsGrams.round()}g with no carbs logged. '
                'Confirm to add it (improves meal insights and the model).',
        confidence: m.confidence,
        carbsGrams: m.estimatedCarbsGrams,
      ));
    }

    // 2. Compression lows: sharp overnight dips with fast rebound.
    final lows = CompressionLowDetector().detect(
      cgm: cgm,
      boluses: boluses,
      basal: basal,
      settings: settings,
      isAsleep: asleep,
    );
    for (final l in lows) {
      if (l.confidence < minConfidence) continue;
      if (_coveredBy(annotations, l.start, const {AnnotationKind.compressionLow})) {
        continue;
      }
      out.add(PendingConfirmation(
        type: ConfirmationType.compressionLow,
        start: l.start,
        end: l.start.add(const Duration(minutes: 15)),
        title: 'Compression low?',
        detail:
            'A sharp overnight dip that rebounded fast — likely sensor pressure, '
                'not a real low. Confirm to exclude it from your stats and the model.',
        confidence: l.confidence,
      ));
    }

    // 3. Site failure (TASK-149): a stubborn high on an old site — insulin not
    // working with the infusion set past its life is the classic failed-site
    // signature. Confirming writes an AnnotationKind.siteFailure annotation so
    // the period is excluded from training as non-physiological.
    final stubborn = const StubbornHighDetector().detect(
      cgm: cgm,
      boluses: boluses,
      basal: basal,
      settings: settings,
      siteAgeHours: siteAgeHours,
      now: now,
    );
    if (stubborn != null && stubborn.likelySiteIssue) {
      // Day-stable start so re-scans dedupe to one entry per day.
      final dayStart =
          DateTime(stubborn.since.year, stubborn.since.month, stubborn.since.day);
      if (!_coveredBy(annotations, stubborn.since,
          const {AnnotationKind.siteFailure})) {
        out.add(PendingConfirmation(
          type: ConfirmationType.siteFailure,
          start: dayStart,
          end: now,
          title: 'Infusion site failing?',
          detail: 'High for a while with '
              '${stubborn.iobUnits.toStringAsFixed(1)} U on board doing little, '
              'and the site is ~${(stubborn.siteAgeHours! / 24).toStringAsFixed(1)} '
              'days old. Confirm to tag the period as a site failure (excluded '
              'from training).',
          // Rule-based signal (no scored confidence): fixed, comfortably above
          // the surfacing floor.
          confidence: 0.7,
        ));
      }
    }

    // 4. Illness: the detector thinks recent data looks illness-like.
    if (illness != null && illness.suggestActivation) {
      final dayStart = DateTime(now.year, now.month, now.day);
      if (!_coveredBy(annotations, dayStart, const {AnnotationKind.illness})) {
        out.add(PendingConfirmation(
          type: ConfirmationType.illness,
          start: dayStart, // day-stable id so it isn't re-queued every scan
          end: now,
          title: 'Feeling unwell?',
          detail: '${illness.reasons.join('; ')}. '
              'Confirm to tag today as illness (raises the sensitivity context).',
          confidence: illness.score.clamp(0.0, 1.0),
        ));
      }
    }

    return out
        .where((p) => !decidedIds.contains(p.id))
        .toList()
      ..sort((a, b) => b.start.compareTo(a.start));
  }

  static bool _coveredBy(
          List<Annotation> annotations, DateTime t, Set<AnnotationKind> kinds) =>
      annotations.any((a) => kinds.contains(a.kind) && a.covers(t));

}
