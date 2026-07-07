/// A medication course (typically glucocorticoids/steroids) that transiently raises
/// insulin resistance. Glucocorticoid-induced hyperglycemia is large and dose-dependent,
/// so while a course is active we bump the sensitivity context toward resistance — the
/// same overlay mechanism illness mode uses — so dosing suggestions and expectations
/// account for it. Advisory only.
library;

import '../analytics/therapy_settings.dart';

enum MedicationIntensity { mild, moderate, high }

extension MedicationIntensityX on MedicationIntensity {
  /// Resistance multiplier applied on top of the base sensitivity context.
  double get resistanceBoost => switch (this) {
        MedicationIntensity.mild => 1.15,
        MedicationIntensity.moderate => 1.25,
        MedicationIntensity.high => 1.40,
      };

  String get label => switch (this) {
        MedicationIntensity.mild => 'Mild',
        MedicationIntensity.moderate => 'Moderate',
        MedicationIntensity.high => 'High',
      };
}

class MedicationMode {
  const MedicationMode({
    this.active = false,
    this.startedAt,
    this.intensity = MedicationIntensity.moderate,
    this.name = 'Steroid',
  });

  final bool active;
  final DateTime? startedAt;
  final MedicationIntensity intensity;
  final String name;

  /// Apply the resistance boost to [base] while active (TASK-146: delegates to
  /// [SensitivityContext.withResistanceOverlay] for the shared clamp/confidence
  /// -floor/dedup math — the same overlay illness mode uses). No-op when inactive.
  SensitivityContext overlay(SensitivityContext base) {
    if (!active) return base;
    return base.withResistanceOverlay(
      boost: intensity.resistanceBoost,
      reason: 'medication',
    );
  }

  MedicationMode copyWith({
    bool? active,
    Object? startedAt = _sentinel,
    MedicationIntensity? intensity,
    String? name,
  }) =>
      MedicationMode(
        active: active ?? this.active,
        startedAt:
            startedAt == _sentinel ? this.startedAt : startedAt as DateTime?,
        intensity: intensity ?? this.intensity,
        name: name ?? this.name,
      );

  Map<String, dynamic> toJson() => {
        'active': active,
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        'intensity': intensity.name,
        'name': name,
      };

  factory MedicationMode.fromJson(Map<String, dynamic> j) => MedicationMode(
        active: j['active'] as bool? ?? false,
        startedAt: j['startedAt'] == null
            ? null
            : DateTime.parse(j['startedAt'] as String),
        intensity: MedicationIntensity.values.asNameMap()[j['intensity']] ??
            MedicationIntensity.moderate,
        name: j['name'] as String? ?? 'Steroid',
      );

  static const _sentinel = Object();
}
