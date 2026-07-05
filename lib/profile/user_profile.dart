/// The user's personal profile — sex, age, diabetes history, and body metrics. Collected
/// in onboarding, editable in Settings, persisted encrypted. Fed into the models only
/// where it's genuinely usable:
///   * biological sex gates the menstrual-cycle features (luteal-phase sensitivity, the
///     cycle report) — they only apply when there's a cycle;
///   * age and diabetes duration raise the low-alert threshold a little, since older age
///     and long-standing T1D are established risk factors for impaired hypo awareness.
///
/// Everything is optional; missing fields simply don't influence anything.
library;

import 'dart:math' as math;

enum BiologicalSex { unspecified, female, male, other }

extension BiologicalSexX on BiologicalSex {
  String get label => switch (this) {
        BiologicalSex.unspecified => 'Prefer not to say',
        BiologicalSex.female => 'Female',
        BiologicalSex.male => 'Male',
        BiologicalSex.other => 'Other / intersex',
      };
}

enum DiabetesType { type1, type2, lada, other }

extension DiabetesTypeX on DiabetesType {
  String get label => switch (this) {
        DiabetesType.type1 => 'Type 1',
        DiabetesType.type2 => 'Type 2',
        DiabetesType.lada => 'LADA',
        DiabetesType.other => 'Other',
      };
}

class UserProfile {
  const UserProfile({
    this.name = '',
    this.sex = BiologicalSex.unspecified,
    this.birthYear,
    this.diagnosisYear,
    this.weightKg,
    this.heightCm,
    this.diabetesType = DiabetesType.type1,
  });

  final String name;
  final BiologicalSex sex;
  final int? birthYear;
  final int? diagnosisYear;
  final double? weightKg;
  final double? heightCm;
  final DiabetesType diabetesType;

  int? ageAt(DateTime now) =>
      birthYear == null ? null : now.year - birthYear!;

  int? diabetesDurationYears(DateTime now) =>
      diagnosisYear == null ? null : now.year - diagnosisYear!;

  /// Only female profiles have a menstrual cycle to model. (Unspecified/other opt out —
  /// the features are still reachable if flow data is logged, but not applied by default.)
  bool get hasMenstrualCycle => sex == BiologicalSex.female;

  double? get bmi => (weightKg != null && heightCm != null && heightCm! > 0)
      ? weightKg! / math.pow(heightCm! / 100.0, 2)
      : null;

  /// True when nothing has been filled in yet.
  bool get isEmpty =>
      name.isEmpty &&
      sex == BiologicalSex.unspecified &&
      birthYear == null &&
      diagnosisYear == null &&
      weightKg == null &&
      heightCm == null;

  UserProfile copyWith({
    String? name,
    BiologicalSex? sex,
    Object? birthYear = _sentinel,
    Object? diagnosisYear = _sentinel,
    Object? weightKg = _sentinel,
    Object? heightCm = _sentinel,
    DiabetesType? diabetesType,
  }) =>
      UserProfile(
        name: name ?? this.name,
        sex: sex ?? this.sex,
        birthYear: birthYear == _sentinel ? this.birthYear : birthYear as int?,
        diagnosisYear:
            diagnosisYear == _sentinel ? this.diagnosisYear : diagnosisYear as int?,
        weightKg: weightKg == _sentinel ? this.weightKg : weightKg as double?,
        heightCm: heightCm == _sentinel ? this.heightCm : heightCm as double?,
        diabetesType: diabetesType ?? this.diabetesType,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'sex': sex.name,
        if (birthYear != null) 'birthYear': birthYear,
        if (diagnosisYear != null) 'diagnosisYear': diagnosisYear,
        if (weightKg != null) 'weightKg': weightKg,
        if (heightCm != null) 'heightCm': heightCm,
        'diabetesType': diabetesType.name,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] as String? ?? '',
        sex: BiologicalSex.values.asNameMap()[j['sex']] ??
            BiologicalSex.unspecified,
        birthYear: (j['birthYear'] as num?)?.toInt(),
        diagnosisYear: (j['diagnosisYear'] as num?)?.toInt(),
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        heightCm: (j['heightCm'] as num?)?.toDouble(),
        diabetesType: DiabetesType.values.asNameMap()[j['diabetesType']] ??
            DiabetesType.type1,
      );

  static const _sentinel = Object();
}

/// Turns risk factors for impaired hypoglycemia awareness (older age, long-standing
/// diabetes) into a small upward bump on the low-alert threshold, so alerts lead more.
class HypoAwarenessRisk {
  const HypoAwarenessRisk({
    this.olderAgeYears = 65,
    this.longDurationYears = 20,
    this.olderBumpMgdl = 5,
    this.longDurationBumpMgdl = 3,
    this.maxBumpMgdl = 8,
  });

  final int olderAgeYears;
  final int longDurationYears;
  final double olderBumpMgdl;
  final double longDurationBumpMgdl;
  final double maxBumpMgdl;

  /// Extra mg/dL to add to the low-alert threshold for [profile].
  double lowThresholdBump(UserProfile profile, DateTime now) {
    var bump = 0.0;
    final age = profile.ageAt(now);
    if (age != null && age >= olderAgeYears) bump += olderBumpMgdl;
    final dur = profile.diabetesDurationYears(now);
    if (dur != null && dur >= longDurationYears) bump += longDurationBumpMgdl;
    return math.min(bump, maxBumpMgdl);
  }
}
