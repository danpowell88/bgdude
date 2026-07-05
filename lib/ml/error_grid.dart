/// Clarke Error Grid analysis for evaluating glucose predictions/estimates against
/// reference values. Zones A–E; clinically we want A+B > 90–95%. This is used both
/// for reporting model quality and as the safety gate before promoting a retrained
/// model (Phase 3/4).
///
/// Zone boundaries follow the original Clarke et al. 1987 definition (mg/dL).
library;

enum ClarkeZone { a, b, c, d, e }

class ErrorGridPoint {
  const ErrorGridPoint({
    required this.referenceMgdl,
    required this.predictedMgdl,
    required this.zone,
  });
  final double referenceMgdl;
  final double predictedMgdl;
  final ClarkeZone zone;
}

class ErrorGridResult {
  const ErrorGridResult(this.points, this.zoneCounts);

  final List<ErrorGridPoint> points;
  final Map<ClarkeZone, int> zoneCounts;

  int get total => points.length;

  double _frac(ClarkeZone z) => total == 0 ? 0 : (zoneCounts[z] ?? 0) / total;

  double get zoneAFraction => _frac(ClarkeZone.a);
  double get zoneBFraction => _frac(ClarkeZone.b);

  /// The clinically-safe fraction (A + B).
  double get abFraction => zoneAFraction + zoneBFraction;

  /// Dangerous fraction: zones D + E (missed treatment / wrong treatment).
  double get dangerousFraction => _frac(ClarkeZone.d) + _frac(ClarkeZone.e);
}

class ClarkeErrorGrid {
  const ClarkeErrorGrid();

  ClarkeZone classify(double reference, double predicted) {
    final ref = reference;
    final pred = predicted;

    // Zone A: within 20% of reference, or both < 70.
    if ((ref <= 70 && pred <= 70) ||
        (pred <= ref * 1.2 && pred >= ref * 0.8)) {
      return ClarkeZone.a;
    }

    // Zone E: reference low but predicted high, or vice-versa (wrong-treatment).
    if ((ref <= 70 && pred >= 180) || (ref >= 180 && pred <= 70)) {
      return ClarkeZone.e;
    }

    // Zone C: over-corrections.
    if ((ref >= 70 && ref <= 290 && pred >= ref + 110) ||
        (ref >= 130 && ref <= 180 && pred <= (7.0 / 5.0) * ref - 182)) {
      return ClarkeZone.c;
    }

    // Zone D: dangerous failure to detect (predicted in-range but reference out).
    if ((ref >= 240 && pred >= 70 && pred <= 180) ||
        (ref <= 70 && pred >= 70 && pred <= 180)) {
      return ClarkeZone.d;
    }

    // Everything else is Zone B (benign errors).
    return ClarkeZone.b;
  }

  ErrorGridResult evaluate(
    List<({double reference, double predicted})> pairs,
  ) {
    final points = <ErrorGridPoint>[];
    final counts = <ClarkeZone, int>{
      for (final z in ClarkeZone.values) z: 0,
    };
    for (final p in pairs) {
      final z = classify(p.reference, p.predicted);
      counts[z] = counts[z]! + 1;
      points.add(ErrorGridPoint(
          referenceMgdl: p.reference, predictedMgdl: p.predicted, zone: z));
    }
    return ErrorGridResult(points, counts);
  }
}

/// Hypoglycaemia-specific detection quality — reported separately from RMSE because a
/// model can post good RMSE yet miss turning points / lows.
class HypoDetectionStats {
  const HypoDetectionStats({
    required this.truePositives,
    required this.falseNegatives,
    required this.falsePositives,
    required this.trueNegatives,
  });

  final int truePositives;
  final int falseNegatives;
  final int falsePositives;
  final int trueNegatives;

  /// Fraction of true lows the model also predicted low. Null when the window
  /// contains no true lows at all — "no lows to detect" is not the same as "missed
  /// every low", and reporting 0 here used to spuriously fail the promotion gate on
  /// hypo-free evaluation windows.
  double? get sensitivity => (truePositives + falseNegatives) == 0
      ? null
      : truePositives / (truePositives + falseNegatives);

  /// Fraction of true not-lows the model wrongly flagged low. Null when the window
  /// contains no true not-lows.
  double? get falseAlarmRate => (falsePositives + trueNegatives) == 0
      ? null
      : falsePositives / (falsePositives + trueNegatives);

  static HypoDetectionStats fromPairs(
    List<({double reference, double predicted})> pairs, {
    double thresholdMgdl = 70,
  }) {
    var tp = 0, fn = 0, fp = 0, tn = 0;
    for (final p in pairs) {
      final refLow = p.reference < thresholdMgdl;
      final predLow = p.predicted < thresholdMgdl;
      if (refLow && predLow) tp++;
      if (refLow && !predLow) fn++;
      if (!refLow && predLow) fp++;
      if (!refLow && !predLow) tn++;
    }
    return HypoDetectionStats(
      truePositives: tp,
      falseNegatives: fn,
      falsePositives: fp,
      trueNegatives: tn,
    );
  }
}
