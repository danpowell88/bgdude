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
    this.expiresAt,
    this.intensity = MedicationIntensity.moderate,
    this.name = 'Steroid',
  });

  final bool active;
  final DateTime? startedAt;

  /// Optional auto-expiry so a forgotten course doesn't inflate dosing
  /// indefinitely (TASK-197). Null = active until manually stopped (e.g. a value
  /// restored from before this field existed).
  final DateTime? expiresAt;
  final MedicationIntensity intensity;
  final String name;

  /// Default course length applied when none is specified — steroid courses/
  /// tapers are typically on the order of one to two weeks.
  static const Duration defaultExpectedDuration = Duration(days: 14);

  bool isExpired(DateTime now) =>
      active && expiresAt != null && now.isAfter(expiresAt!);

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
    Object? expiresAt = _sentinel,
    MedicationIntensity? intensity,
    String? name,
  }) =>
      MedicationMode(
        active: active ?? this.active,
        startedAt:
            startedAt == _sentinel ? this.startedAt : startedAt as DateTime?,
        expiresAt:
            expiresAt == _sentinel ? this.expiresAt : expiresAt as DateTime?,
        intensity: intensity ?? this.intensity,
        name: name ?? this.name,
      );

  Map<String, dynamic> toJson() => {
        'active': active,
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'intensity': intensity.name,
        'name': name,
      };

  factory MedicationMode.fromJson(Map<String, dynamic> j) {
    final startedAt = j['startedAt'] == null
        ? null
        : DateTime.parse(j['startedAt'] as String);
    return MedicationMode(
      // TASK-304: mirrors IllnessMode.fromJson -- a corrupt/tampered
      // active=true + startedAt=null combo must not decode as active, since
      // deactivateIfExpired's annotation builder reads startedAt! unconditionally
      // once a mode is both active and expired.
      active: (j['active'] as bool? ?? false) && startedAt != null,
      startedAt: startedAt,
      expiresAt: j['expiresAt'] == null
          ? null
          : DateTime.parse(j['expiresAt'] as String),
      intensity: MedicationIntensity.values.asNameMap()[j['intensity']] ??
          MedicationIntensity.moderate,
      name: j['name'] as String? ?? 'Steroid',
    );
  }

  static const _sentinel = Object();
}
