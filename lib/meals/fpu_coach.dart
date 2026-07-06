/// Fat-Protein Unit (Warsaw/Pankowska) dosing help. High-fat / high-protein meals cause
/// a delayed, prolonged glucose rise (the "pizza effect") that carb counting misses. One
/// FPU = 100 kcal of fat+protein and calls for roughly the insulin of 10 g of carb, best
/// delivered *extended* over several hours rather than up front.
///
/// Advisory only — the app never doses. This surfaces a suggested split + a delayed-rise
/// watch window for the user to act on themselves.
library;

import '../analytics/bolus_advisor.dart';

class FpuAdvice {
  const FpuAdvice({
    required this.fpu,
    required this.immediateUnits,
    required this.extendedUnits,
    required this.extendHours,
    required this.recommendSplit,
    required this.delayedRiseFromHours,
    required this.delayedRiseToHours,
  });

  /// Fat-protein units = (fat·9 + protein·4) / 100.
  final double fpu;

  /// Insulin for the carbs (deliver now).
  final double immediateUnits;

  /// Insulin attributable to fat/protein (deliver extended).
  final double extendedUnits;

  /// Suggested duration to extend [extendedUnits] over.
  final int extendHours;

  /// Whether the fat/protein load is big enough to bother splitting.
  final bool recommendSplit;

  final int delayedRiseFromHours;
  final int delayedRiseToHours;

  double get totalUnits => immediateUnits + extendedUnits;

  static const FpuAdvice none = FpuAdvice(
    fpu: 0,
    immediateUnits: 0,
    extendedUnits: 0,
    extendHours: 0,
    recommendSplit: false,
    delayedRiseFromHours: 3,
    delayedRiseToHours: 5,
  );
}

class FpuCoach {
  const FpuCoach({
    this.carbEquivPerFpu = 10,
    this.minFpuForSplit = 1.0,
    this.delayedRiseFromHours = 3,
    this.delayedRiseToHours = 5,
  });

  /// 1 FPU ≈ this many grams of carb for insulin purposes (Pankowska).
  final double carbEquivPerFpu;
  final double minFpuForSplit;
  final int delayedRiseFromHours;
  final int delayedRiseToHours;

  /// [insulinToCarbRatio] is grams of carb per unit (ICR).
  FpuAdvice advise({
    required double carbsGrams,
    required double fatGrams,
    required double proteinGrams,
    required double insulinToCarbRatio,
  }) {
    if (insulinToCarbRatio <= 0) return FpuAdvice.none;
    final fpu = (fatGrams * 9 + proteinGrams * 4) / 100.0;
    final immediate = carbsGrams / insulinToCarbRatio;
    final extended = (fpu * carbEquivPerFpu) / insulinToCarbRatio;
    // Pankowska: the published step table (1→3 h, 2→4 h, 3→5 h, ≥4→8 h), shared
    // with the bolus advisor so the two surfaces can't drift (TASK-162).
    final extendHours = BolusAdvisor.pankowskaExtendHours(fpu);
    return FpuAdvice(
      fpu: fpu,
      immediateUnits: immediate,
      extendedUnits: extended,
      extendHours: extendHours,
      recommendSplit: fpu >= minFpuForSplit,
      delayedRiseFromHours: delayedRiseFromHours,
      delayedRiseToHours: delayedRiseToHours,
    );
  }

  /// Convenience: whether a meal (with optional macros) warrants FPU handling.
  bool warrantsSplit({
    required double fatGrams,
    required double proteinGrams,
    bool fatProteinHeavy = false,
  }) {
    final fpu = (fatGrams * 9 + proteinGrams * 4) / 100.0;
    return fpu >= minFpuForSplit || (fpu == 0 && fatProteinHeavy);
  }
}
