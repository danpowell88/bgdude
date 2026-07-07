/// Illness mode: a user-activated (and model-suggested) temporary mode for sick days.
///
/// Illness reliably raises insulin resistance and ketone risk, so while active the
/// mode (a) overlays the sensitivity context with a user-tunable resistance boost,
/// (b) biases the bolus advisor conservative-high-alert via extra advice notes, and
/// (c) on deactivation emits an [AnnotationKind.illness] annotation spanning the sick
/// period so the retraining pipeline tags (rather than mislearns) those days.
///
/// `IllnessDetector` scores the last 24–48h against the user's own baselines and
/// suggests activation when the data looks illness-like (sustained glucose elevation,
/// raised resting HR, suppressed HRV, collapsed step count).
///
/// Pure Dart — no Flutter imports — so everything here is unit-testable off-device.
library;

import 'dart:convert';

import '../analytics/therapy_settings.dart';
import '../feedback/annotations.dart';

/// Persistent illness-mode state. JSON round-trips so it can be stored in
/// shared_preferences and survive app restarts mid-illness.
class IllnessMode {
  const IllnessMode({
    this.active = false,
    this.startedAt,
    this.expiresAt,
    this.expectedResistanceBoost = defaultBoost,
    this.notes = '',
  })  : assert(expectedResistanceBoost >= minBoost &&
            expectedResistanceBoost <= maxBoost),
        assert(!active || startedAt != null,
            'an active illness mode must have a start time');

  /// User-adjustable bounds for the resistance boost slider.
  static const double minBoost = 1.0;
  static const double maxBoost = 1.5;

  /// Typical sick-day resistance increase (~20%) — the starting point, not gospel.
  static const double defaultBoost = 1.2;

  /// Auto-expiry applied when activating with no explicit duration (TASK-197): a
  /// sick-day episode is typically a matter of days, not weeks, so 7 days is a
  /// generous default that still guards against a forgotten mode silently
  /// inflating dosing indefinitely.
  static const Duration defaultExpectedDuration = Duration(days: 7);

  final bool active;

  /// When the mode was switched on (null while inactive).
  final DateTime? startedAt;

  /// Optional auto-expiry so a forgotten mode doesn't inflate dosing for weeks.
  /// Null = active until manually deactivated.
  final DateTime? expiresAt;

  /// Multiplier applied on top of the model's resistance multiplier while sick.
  final double expectedResistanceBoost;

  /// Free-text ("head cold", "gastro day 2") — carried onto the annotation.
  final String notes;

  static const IllnessMode inactive = IllnessMode();

  /// How long the mode has been running (null while inactive).
  Duration? activeFor(DateTime now) =>
      active && startedAt != null ? now.difference(startedAt!) : null;

  bool isExpired(DateTime now) =>
      active && expiresAt != null && now.isAfter(expiresAt!);

  IllnessMode copyWith({
    double? expectedResistanceBoost,
    String? notes,
  }) =>
      IllnessMode(
        active: active,
        startedAt: startedAt,
        expiresAt: expiresAt,
        expectedResistanceBoost: (expectedResistanceBoost ??
                this.expectedResistanceBoost)
            .clamp(minBoost, maxBoost)
            .toDouble(),
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'active': active,
        'startedAt': startedAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'expectedResistanceBoost': expectedResistanceBoost,
        'notes': notes,
      };

  factory IllnessMode.fromJson(Map<String, dynamic> json) {
    final startedAt = json['startedAt'] == null
        ? null
        : DateTime.parse(json['startedAt'] as String);
    return IllnessMode(
      active: (json['active'] as bool? ?? false) && startedAt != null,
      startedAt: startedAt,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      expectedResistanceBoost:
          ((json['expectedResistanceBoost'] as num?)?.toDouble() ??
                  defaultBoost)
              .clamp(minBoost, maxBoost)
              .toDouble(),
      notes: json['notes'] as String? ?? '',
    );
  }

  /// String helpers for shared_preferences storage.
  String encode() => jsonEncode(toJson());

  static IllnessMode decode(String raw) =>
      IllnessMode.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Owns an [IllnessMode] and derives everything the rest of the app consumes from
/// it: the sensitivity-context overlay, the retraining annotation, and the advice
/// notes for the bolus advisor. State-management wrappers (Riverpod) sit above this.
class IllnessModeController {
  IllnessModeController({IllnessMode initial = IllnessMode.inactive})
      : mode = initial;

  IllnessMode mode;

  /// Switch illness mode on (or update its boost/notes if already on).
  void activate({
    required DateTime now,
    double? expectedResistanceBoost,
    String? notes,
    Duration? expectedDuration,
  }) {
    mode = IllnessMode(
      active: true,
      startedAt: mode.active ? mode.startedAt : now,
      expiresAt: expectedDuration == null
          ? mode.expiresAt
          : now.add(expectedDuration),
      expectedResistanceBoost:
          (expectedResistanceBoost ?? mode.expectedResistanceBoost)
              .clamp(IllnessMode.minBoost, IllnessMode.maxBoost)
              .toDouble(),
      notes: notes ?? mode.notes,
    );
  }

  /// Switch off and return the annotation covering the sick period (for the caller
  /// to persist into the feedback store). Returns null if it wasn't active.
  Annotation? deactivate(DateTime now) {
    if (!mode.active) return null;
    final annotation = buildAnnotation(now);
    mode = IllnessMode(
      active: false,
      expectedResistanceBoost: mode.expectedResistanceBoost,
    );
    return annotation;
  }

  /// Push the auto-expiry out by [by] (sets one if none existed).
  void extend(Duration by, {required DateTime now}) {
    if (!mode.active) return;
    final base = mode.expiresAt ?? now;
    mode = IllnessMode(
      active: true,
      startedAt: mode.startedAt,
      expiresAt: (base.isBefore(now) ? now : base).add(by),
      expectedResistanceBoost: mode.expectedResistanceBoost,
      notes: mode.notes,
    );
  }

  /// Deactivate if the expiry has passed; returns the annotation when it fired.
  Annotation? deactivateIfExpired(DateTime now) =>
      mode.isExpired(now) ? deactivate(now) : null;

  void updateBoost(double boost) =>
      mode = mode.copyWith(expectedResistanceBoost: boost);

  void updateNotes(String notes) => mode = mode.copyWith(notes: notes);

  /// The sensitivity context the rest of the app should use while sick (TASK-146):
  /// delegates to [SensitivityContext.withResistanceOverlay] for the shared
  /// clamp/confidence-floor/dedup math. The advisor should not treat this
  /// adjustment as a weak signal — illness → resistance is well-established — so
  /// this relies on the helper's default confidence floor even when the learned
  /// model is still cold.
  SensitivityContext overlay(SensitivityContext base) {
    if (!mode.active) return base;
    return base.withResistanceOverlay(
      boost: mode.expectedResistanceBoost,
      reason: 'illness',
    );
  }

  /// The context annotation spanning the active period, ending at [now]. Feeds the
  /// retraining pipeline ([AnnotationKind.illness] is `isContext`, so those days
  /// train the sensitivity model rather than being silently mislearned).
  Annotation buildAnnotation(DateTime now) {
    assert(mode.active && mode.startedAt != null,
        'buildAnnotation requires an active illness mode');
    final start = mode.startedAt!;
    return Annotation(
      id: 'illness-${start.millisecondsSinceEpoch}',
      kind: AnnotationKind.illness,
      start: start,
      end: now.isBefore(start) ? start : now,
      note: mode.notes,
      confidence: 1.0,
    );
  }

  /// Extra notes the bolus advisor should append to its advice while sick —
  /// conservative-high-alert: expect resistance, watch for ketones.
  List<String> get adviceNotes => mode.active
      ? const [
          'Illness mode: expect higher insulin needs; check ketones if high with '
              'normal IOB.',
          'Stay hydrated; consider more frequent corrections per your sick-day '
              'rules.',
        ]
      : const [];
}

/// Result of an illness-likelihood evaluation over the last 24–48h.
class IllnessSuggestion {
  const IllnessSuggestion({
    required this.score,
    required this.reasons,
    required this.suggestActivation,
  });

  /// 0..1 illness likelihood.
  final double score;

  /// Human-readable contributing signals ("glucose ~29% above 14-day baseline").
  final List<String> reasons;

  /// True when [score] crossed the detector's threshold.
  final bool suggestActivation;

  static const IllnessSuggestion none =
      IllnessSuggestion(score: 0, reasons: [], suggestActivation: false);
}

/// Scores how illness-like the recent data looks, relative to the user's own
/// baselines (passed in — the detector holds no state and fetches nothing).
///
/// Weighted signals, each graded 0..1 (full credit at its threshold deviation,
/// partial credit from half-threshold, zero below):
///   * mean glucose >20% above the 14-day baseline mean   (weight .40)
///   * resting HR   > 8% above baseline                   (weight .25)
///   * HRV          >15% below baseline                   (weight .20)
///   * steps        <40% of baseline (i.e. >60% reduction) (weight .15)
///
/// Only signals whose inputs are present count; the remaining weights are
/// renormalised so missing wearable data can't dilute a clear glucose signal.
class IllnessDetector {
  const IllnessDetector({this.suggestionThreshold = 0.6});

  /// Score at/above which activation is suggested.
  final double suggestionThreshold;

  static const double _glucoseWeight = 0.40;
  static const double _restingHrWeight = 0.25;
  static const double _hrvWeight = 0.20;
  static const double _stepsWeight = 0.15;

  static const double _glucoseThreshold = 0.20; // fractional elevation
  static const double _restingHrThreshold = 0.08; // fractional elevation
  static const double _hrvThreshold = 0.15; // fractional suppression
  static const double _stepsThreshold = 0.60; // fractional reduction

  IllnessSuggestion detect({
    /// Mean glucose over the last 24–48h, mg/dL.
    double? meanGlucoseMgdl,

    /// The user's 14-day baseline mean glucose, mg/dL.
    double? baselineGlucoseMgdl,
    double? restingHr,
    double? baselineRestingHr,
    double? hrvRmssd,
    double? baselineHrv,
    double? dailySteps,
    double? baselineDailySteps,
    // Extended illness signals from Health Connect.
    double? bodyTempC,
    double? baselineBodyTempC,
    double? respiratoryRate,
    double? baselineRespiratoryRate,
    double? spo2,
    double? baselineSpo2,
  }) {
    var weightSum = 0.0;
    var weightedScore = 0.0;
    final reasons = <String>[];

    void signal({
      required double? value,
      required double? baseline,
      required double weight,
      required double threshold,
      required double Function(double value, double baseline) deviation,
      required String Function(double deviation) describe,
    }) {
      if (value == null || baseline == null || baseline <= 0) return;
      weightSum += weight;
      final dev = deviation(value, baseline);
      final score = _grade(dev, threshold);
      weightedScore += weight * score;
      if (score > 0) reasons.add(describe(dev));
    }

    signal(
      value: meanGlucoseMgdl,
      baseline: baselineGlucoseMgdl,
      weight: _glucoseWeight,
      threshold: _glucoseThreshold,
      deviation: (v, b) => v / b - 1.0,
      describe: (d) =>
          'glucose ~${(d * 100).round()}% above 14-day baseline',
    );
    signal(
      value: restingHr,
      baseline: baselineRestingHr,
      weight: _restingHrWeight,
      threshold: _restingHrThreshold,
      deviation: (v, b) => v / b - 1.0,
      describe: (d) => 'resting HR ~${(d * 100).round()}% above baseline',
    );
    signal(
      value: hrvRmssd,
      baseline: baselineHrv,
      weight: _hrvWeight,
      threshold: _hrvThreshold,
      deviation: (v, b) => 1.0 - v / b,
      describe: (d) => 'HRV ~${(d * 100).round()}% below baseline',
    );
    signal(
      value: dailySteps,
      baseline: baselineDailySteps,
      weight: _stepsWeight,
      threshold: _stepsThreshold,
      deviation: (v, b) => 1.0 - v / b,
      describe: (d) => 'steps ~${(d * 100).round()}% below baseline',
    );
    // Fever: absolute body-temp rise over baseline (°C).
    signal(
      value: bodyTempC,
      baseline: baselineBodyTempC,
      weight: 0.25,
      threshold: 0.7,
      deviation: (v, b) => v - b,
      describe: (d) => 'temperature ~${d.toStringAsFixed(1)}°C above baseline',
    );
    // Elevated respiratory rate.
    signal(
      value: respiratoryRate,
      baseline: baselineRespiratoryRate,
      weight: 0.12,
      threshold: 0.15,
      deviation: (v, b) => v / b - 1.0,
      describe: (d) => 'respiratory rate ~${(d * 100).round()}% above baseline',
    );
    // Lowered blood-oxygen (absolute % drop).
    signal(
      value: spo2,
      baseline: baselineSpo2,
      weight: 0.12,
      threshold: 2.0,
      deviation: (v, b) => b - v,
      describe: (d) => 'SpO₂ ~${d.toStringAsFixed(0)}% below baseline',
    );

    if (weightSum == 0) return IllnessSuggestion.none;

    final score = (weightedScore / weightSum).clamp(0.0, 1.0).toDouble();
    return IllnessSuggestion(
      score: score,
      reasons: reasons,
      suggestActivation: score >= suggestionThreshold,
    );
  }

  /// 0 below half the threshold, linear ramp to 1 at the threshold, 1 beyond —
  /// so ordinary day-to-day wobble contributes nothing while a borderline signal
  /// still gets partial credit.
  double _grade(double deviation, double threshold) {
    final half = threshold / 2;
    if (deviation <= half) return 0;
    if (deviation >= threshold) return 1;
    return (deviation - half) / half;
  }
}
