/// The unified "day stream" event model. Everything that happened today — meals,
/// boluses, detected unannounced meals, highs/lows, exercise, compression lows, sensor
/// changes — becomes a [DayEvent] the user can review on one page and *tag* for how the
/// models should treat it (use it, or ignore it because of illness / a new CGM sensor /
/// a new infusion site / a compression artefact, etc.).
///
/// The tag maps onto the feedback layer: an "ignore" disposition writes an
/// [AnnotationKind] that the retraining pipeline already knows how to exclude/relabel.
library;

import '../feedback/annotations.dart';

enum DayEventType {
  meal,
  bolus,
  detectedMeal,
  high,
  low,
  compressionLow,
  exercise,
  sensorChange,
  siteChange,
  prediction,
}

extension DayEventTypeX on DayEventType {
  String get label => switch (this) {
        DayEventType.meal => 'Meal',
        DayEventType.bolus => 'Bolus',
        DayEventType.detectedMeal => 'Unannounced rise',
        DayEventType.high => 'High',
        DayEventType.low => 'Low',
        DayEventType.compressionLow => 'Compression low',
        DayEventType.exercise => 'Exercise',
        DayEventType.sensorChange => 'New sensor',
        DayEventType.siteChange => 'New infusion site',
        DayEventType.prediction => 'Prediction',
      };

  String get emoji => switch (this) {
        DayEventType.meal => '🍽️',
        DayEventType.bolus => '💉',
        DayEventType.detectedMeal => '📈',
        DayEventType.high => '🔺',
        DayEventType.low => '🔻',
        DayEventType.compressionLow => '🛏️',
        DayEventType.exercise => '🏃',
        DayEventType.sensorChange => '🩹',
        DayEventType.siteChange => '🧷',
        DayEventType.prediction => '🔮',
      };
}

/// How the models should treat an event.
enum ModelDisposition {
  /// Default — the event is real signal and trains the models.
  use,

  /// Excluded from training for a reason (annotation attached).
  ignore,
}

/// Why an event was marked ignore — maps to an [AnnotationKind] the retraining
/// pipeline understands.
enum IgnoreReason {
  compressionLow,
  sensorWarmup,
  siteFailure,
  illness,
  missedCarbs,
  other;

  String get label => switch (this) {
        IgnoreReason.compressionLow => 'Compression low',
        IgnoreReason.sensorWarmup => 'New sensor / warm-up',
        IgnoreReason.siteFailure => 'Infusion site issue',
        IgnoreReason.illness => 'Illness',
        IgnoreReason.missedCarbs => 'Missed carbs',
        IgnoreReason.other => 'Other',
      };

  AnnotationKind get annotationKind => switch (this) {
        IgnoreReason.compressionLow => AnnotationKind.compressionLow,
        IgnoreReason.sensorWarmup => AnnotationKind.sensorWarmup,
        IgnoreReason.siteFailure => AnnotationKind.siteFailure,
        IgnoreReason.illness => AnnotationKind.illness,
        IgnoreReason.missedCarbs => AnnotationKind.missedCarbs,
        IgnoreReason.other => AnnotationKind.other,
      };
}

class DayEvent {
  const DayEvent({
    required this.id,
    required this.type,
    required this.time,
    required this.title,
    required this.detail,
    this.endTime,
    this.mgdl,
    this.suggestedCarbsGrams,
    this.explainable = false,
    this.disposition = ModelDisposition.use,
    this.ignoreReason,
  });

  final String id;
  final DayEventType type;
  final DateTime time;
  final DateTime? endTime;
  final String title;
  final String detail;

  /// Glucose at the event, where relevant.
  final double? mgdl;

  /// For detected meals — the carb estimate a one-tap accept would log.
  final double? suggestedCarbsGrams;

  /// Whether "Explain this" is offered (highs/lows/detected events).
  final bool explainable;

  final ModelDisposition disposition;
  final IgnoreReason? ignoreReason;

  DayEvent copyWith({
    ModelDisposition? disposition,
    IgnoreReason? ignoreReason,
  }) =>
      DayEvent(
        id: id,
        type: type,
        time: time,
        endTime: endTime,
        title: title,
        detail: detail,
        mgdl: mgdl,
        suggestedCarbsGrams: suggestedCarbsGrams,
        explainable: explainable,
        disposition: disposition ?? this.disposition,
        ignoreReason: ignoreReason ?? this.ignoreReason,
      );

  /// The annotation to persist when this event is ignored (null when used).
  Annotation? toAnnotation() {
    if (disposition != ModelDisposition.ignore || ignoreReason == null) {
      return null;
    }
    return Annotation(
      id: 'evt-$id',
      kind: ignoreReason!.annotationKind,
      start: time,
      end: endTime ?? time.add(const Duration(minutes: 30)),
      carbsGrams: ignoreReason == IgnoreReason.missedCarbs
          ? (suggestedCarbsGrams ?? 0)
          : 0,
    );
  }
}
