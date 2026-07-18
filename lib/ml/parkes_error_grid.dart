/// Parkes (Consensus) Error Grid — a newer, more widely-accepted alternative to the
/// Clarke Error Grid for the same purpose: grading how *clinically dangerous* a glucose
/// prediction/estimate error is, not just how numerically large it is.
///
/// Zone boundaries follow the original Type 1 diabetes consensus (100 clinicians polled
/// at the 1994 ADA meeting), as published in:
///   Parkes, J. L., S. L. Slatin, S. Pardo, and B. H. Ginsberg. "A New Consensus Error
///   Grid to Evaluate the Clinical Significance of Inaccuracies in the Measurement of
///   Blood Glucose." Diabetes Care 23, no. 8 (2000): 1143-48.
///   Pfützner, A., D. C. Klonoff, S. Pardo, and J. L. Parkes. "Technical Aspects of the
///   Parkes Error Grid." J Diabetes Sci Technol 7, no. 5 (2013): 1275-81.
///
/// Ported from the peer-reviewed, citable `ega` R package's `getParkesZones` (CRAN;
/// github.com/cran/ega/blob/master/R/ega.R), which is the reference implementation this
/// codebase could actually verify (the published papers' own tables render inconsistently
/// through automated extraction — the R source is exact, numeric, and cites the same two
/// papers). Zone regions are point-in-polygon per Table 1's coordinates; the polygons are
/// extended to [_farMgdl] (well past any real CGM/meter reading) rather than a
/// data-dependent plot limit, since that's a plotting concern the R package needed and
/// this classifier doesn't.
///
/// **One deliberate deviation from `ega` (issue #381).** Its Type 1 D-lower boundary
/// extrapolates from (410, 110), a point that is not on the line its own slope is
/// defined from — a copy-paste from the Type 2 block, where (410, 110) IS a real vertex.
/// The result is a boundary that drifts progressively above Table 1 (by ~4.5 mg/dL at a
/// reference of 550), reporting some pairs as zone D that the published grid puts in
/// zone C. We follow Table 1, not `ega`, and anchor on (250, 40). If you are diffing this
/// file against the R source, that difference is intentional — do not "fix" it back.
library;

enum ParkesZone { a, b, c, d, e }

class ParkesGridPoint {
  const ParkesGridPoint({
    required this.referenceMgdl,
    required this.predictedMgdl,
    required this.zone,
  });
  final double referenceMgdl;
  final double predictedMgdl;
  final ParkesZone zone;
}

class ParkesGridResult {
  const ParkesGridResult(this.points, this.zoneCounts);

  final List<ParkesGridPoint> points;
  final Map<ParkesZone, int> zoneCounts;

  int get total => points.length;

  double _frac(ParkesZone z) => total == 0 ? 0 : (zoneCounts[z] ?? 0) / total;

  double get zoneAFraction => _frac(ParkesZone.a);
  double get zoneBFraction => _frac(ParkesZone.b);

  /// The clinically-safe fraction (A + B).
  double get abFraction => zoneAFraction + zoneBFraction;

  /// Dangerous fraction: zones D + E (missed treatment / wrong treatment).
  double get dangerousFraction => _frac(ParkesZone.d) + _frac(ParkesZone.e);
}

/// A closed polygon in (referenceMgdl, predictedMgdl) space.
typedef _Polygon = List<(double, double)>;

class ParkesErrorGrid {
  const ParkesErrorGrid();

  /// Extend every boundary line this far past its last published anchor point — well
  /// beyond any real CGM (~40-400 mg/dL) or lab meter (up to ~600 mg/dL) reading, so the
  /// choice of "far enough" can't affect a real classification.
  static const double _farMgdl = 1000.0;

  static double _slope(double x, double y, double xEnd, double yEnd) =>
      (yEnd - y) / (xEnd - x);

  /// The y-value on the line through (startX, startY) with [slope], at x = [atX].
  static double _yAt(double startX, double startY, double atX, double slope) =>
      startY + (atX - startX) * slope;

  /// The x-value on the line through (startX, startY) with [slope], at y = [atY].
  static double _xAt(double startX, double startY, double atY, double slope) =>
      startX + (atY - startY) / slope;

  /// Ray-casting point-in-polygon test (even-odd rule).
  static bool _contains(_Polygon poly, double px, double py) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final (xi, yi) = poly[i];
      final (xj, yj) = poly[j];
      final crosses = (yi > py) != (yj > py);
      if (crosses && px < (xj - xi) * (py - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  // --- Type 1 diabetes zone polygons (Table 1) ---

  static final double _ce = _slope(35, 155, 50, 550);
  static final double _cDu = _slope(80, 215, 125, 550);
  static final double _cDl = _slope(250, 40, 550, 150);
  static final double _cCu = _slope(70, 110, 260, 550);
  static final double _cCl = _slope(260, 130, 550, 250);
  static final double _cBu = _slope(280, 380, 430, 550);
  static final double _cBl = _slope(385, 300, 550, 450);

  static _Polygon get _zoneE => [
        (0, 150),
        (35, 155),
        (_xAt(35, 155, _farMgdl, _ce), _farMgdl),
        (0, _farMgdl),
      ];

  static _Polygon get _zoneDLower => [
        (250, 0),
        (250, 40),
        // Issue #381: extrapolate from (250, 40) — this polygon's OWN vertex, and the
        // point _cDl's slope is defined from. The `ega` R package anchors this on
        // (410, 110) instead, which is not on that line (the line is at 98.67 there),
        // so its top edge runs at slope 0.38178 rather than Table 1's 0.36667 and
        // drifts further above the published boundary the higher the reference value.
        // That is an upstream bug, faithfully ported and now corrected; every other
        // polygon here (e.g. _zoneCLower) already anchors on its own vertex.
        (_farMgdl, _yAt(250, 40, _farMgdl, _cDl)),
        (_farMgdl, 0),
      ];

  static _Polygon get _zoneDUpper => [
        (0, 100),
        (25, 100),
        (50, 125),
        (80, 215),
        (_xAt(80, 215, _farMgdl, _cDu), _farMgdl),
        (0, _farMgdl),
      ];

  static _Polygon get _zoneCLower => [
        (120, 0),
        (120, 30),
        (260, 130),
        (_farMgdl, _yAt(260, 130, _farMgdl, _cCl)),
        (_farMgdl, 0),
      ];

  static _Polygon get _zoneCUpper => [
        (0, 60),
        (30, 60),
        (50, 80),
        (70, 110),
        (_xAt(70, 110, _farMgdl, _cCu), _farMgdl),
        (0, _farMgdl),
      ];

  static _Polygon get _zoneBLower => [
        (50, 0),
        (50, 30),
        (170, 145),
        (385, 300),
        (_farMgdl, _yAt(385, 300, _farMgdl, _cBl)),
        (_farMgdl, 0),
      ];

  static _Polygon get _zoneBUpper => [
        (0, 50),
        (30, 50),
        (140, 170),
        (280, 380),
        (_xAt(280, 380, _farMgdl, _cBu), _farMgdl),
        (0, _farMgdl),
      ];

  /// Classify one (reference, predicted) pair. Later checks win on any overlap, matching
  /// the reference implementation's unconditional-overwrite order: B, then C, then D,
  /// then E (E is the most dangerous, so it's checked last and takes priority).
  ParkesZone classify(double reference, double predicted) {
    var zone = ParkesZone.a;
    if (_contains(_zoneBLower, reference, predicted) ||
        _contains(_zoneBUpper, reference, predicted)) {
      zone = ParkesZone.b;
    }
    if (_contains(_zoneCLower, reference, predicted) ||
        _contains(_zoneCUpper, reference, predicted)) {
      zone = ParkesZone.c;
    }
    if (_contains(_zoneDLower, reference, predicted) ||
        _contains(_zoneDUpper, reference, predicted)) {
      zone = ParkesZone.d;
    }
    if (_contains(_zoneE, reference, predicted)) {
      zone = ParkesZone.e;
    }
    return zone;
  }

  ParkesGridResult evaluate(
    List<({double reference, double predicted})> pairs,
  ) {
    final points = <ParkesGridPoint>[];
    final counts = <ParkesZone, int>{for (final z in ParkesZone.values) z: 0};
    for (final p in pairs) {
      final z = classify(p.reference, p.predicted);
      counts[z] = counts[z]! + 1;
      points.add(ParkesGridPoint(
          referenceMgdl: p.reference, predictedMgdl: p.predicted, zone: z));
    }
    return ParkesGridResult(points, counts);
  }
}
