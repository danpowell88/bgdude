/// User annotations: how the user explains model misses and unusual days. These both
/// improve insights and, crucially, gate/relabel the training data so a bad day doesn't
/// teach the model the wrong lesson.
library;

/// The kind of annotation. Some *exclude* a window from training (the model shouldn't
/// learn from a site failure); others *relabel* it (missed carbs adds a carb event);
/// others *tag context* (illness feeds the sensitivity model).
enum AnnotationKind {
  missedCarbs, // relabel: add carbs the pump never saw
  extraCarbs, // relabel: user ate more than entered
  siteFailure, // exclude: infusion set not delivering
  sensorWarmup, // exclude: unreliable readings
  compressionLow, // exclude: pressure artifact (also auto-detected)
  exercise, // context + partial exclude
  illness, // context: raises resistance
  stress, // context: raises resistance
  mood, // context: wellbeing note (great/ok/low)
  alcohol, // context: biases toward delayed lows
  other,
  // Appended last: persisted as AnnotationKind.index (database.dart's `kind` column
  // stores the raw int), so inserting anywhere but the end would silently relabel
  // every already-persisted annotation whose kind shifted -- always append here.
  medication, // context: raises resistance (e.g. a steroid course), TASK-261
}

extension AnnotationKindX on AnnotationKind {
  /// Whether the window should be dropped from forecaster training loss.
  bool get excludesFromTraining => switch (this) {
        AnnotationKind.siteFailure => true,
        AnnotationKind.sensorWarmup => true,
        AnnotationKind.compressionLow => true,
        _ => false,
      };

  /// Whether it contributes a carb relabel.
  bool get relabelsCarbs => switch (this) {
        AnnotationKind.missedCarbs => true,
        AnnotationKind.extraCarbs => true,
        _ => false,
      };

  /// Whether it feeds the sensitivity/context model.
  bool get isContext => switch (this) {
        AnnotationKind.illness => true,
        AnnotationKind.medication => true,
        AnnotationKind.stress => true,
        AnnotationKind.mood => true,
        AnnotationKind.exercise => true,
        AnnotationKind.alcohol => true,
        _ => false,
      };

  String get label => switch (this) {
        AnnotationKind.missedCarbs => 'Missed carbs',
        AnnotationKind.extraCarbs => 'Ate more than entered',
        AnnotationKind.siteFailure => 'Pump/site failure',
        AnnotationKind.sensorWarmup => 'Sensor warm-up / error',
        AnnotationKind.compressionLow => 'Compression low',
        AnnotationKind.exercise => 'Exercise',
        AnnotationKind.illness => 'Illness',
        AnnotationKind.medication => 'Medication',
        AnnotationKind.stress => 'Stress',
        AnnotationKind.mood => 'Mood',
        AnnotationKind.alcohol => 'Alcohol',
        AnnotationKind.other => 'Other',
      };
}

class Annotation {
  const Annotation({
    required this.id,
    required this.kind,
    required this.start,
    required this.end,
    this.carbsGrams = 0,
    this.note = '',
    this.confidence = 1.0,
  });

  final String id;
  final AnnotationKind kind;
  final DateTime start;
  final DateTime end;

  /// For carb relabels.
  final double carbsGrams;
  final String note;

  /// User-expressed certainty (drives sample weighting in retraining).
  final double confidence;

  bool covers(DateTime t) => !t.isBefore(start) && !t.isAfter(end);
}
