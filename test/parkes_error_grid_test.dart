import 'package:bgdude/ml/parkes_error_grid.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-26: reference points for each Parkes (Consensus) zone, Type 1 diabetes,
/// hand-verified against the zone polygons ported from the peer-reviewed `ega` R
/// package (github.com/cran/ega — itself citing Parkes et al. 2000 and Pfützner et
/// al. 2013). Mirrors the pinning style already used for the Clarke grid
/// (metrics_test.dart, TASK-160).
void main() {
  group('ParkesErrorGrid (TASK-26)', () {
    const grid = ParkesErrorGrid();

    test('the identity line is zone A', () {
      expect(grid.classify(100, 100), ParkesZone.a);
    });

    test('a benign, clinically-inconsequential error is zone B', () {
      // Well inside the B-upper polygon: above the (140,170)-(280,380) edge
      // (boundary height at x=200 is 260), short of the C-upper boundary
      // (boundary x at y=300 is ~152, well left of our x=200).
      expect(grid.classify(200, 300), ParkesZone.b);
    });

    test('a moderate over-read is zone C', () {
      // On the diagonal segment past x=70: the C-upper boundary height at x=100
      // is ~179.5 (below our y=250) and the D-upper boundary height there is
      // ~363.9 (above our y=250) — inside both B and C but short of D, so C wins.
      expect(grid.classify(100, 250), ParkesZone.c);
    });

    test('a dangerous over-read is zone D', () {
      // Above the D-upper staircase at x=60 (155) and left of zone E's boundary
      // at that height (x=35.95 at y=180) — inside D but not E.
      expect(grid.classify(60, 180), ParkesZone.d);
    });

    test('reference critically low but predicted high is zone E', () {
      // Inside zone E's narrow upper-left region (right edge at y=200 is x=36.7).
      expect(grid.classify(10, 200), ParkesZone.e);
    });

    test('evaluate() pools zone counts and fractions', () {
      final result = grid.evaluate(const [
        (reference: 100.0, predicted: 100.0), // A
        (reference: 100.0, predicted: 100.0), // A
        (reference: 200.0, predicted: 300.0), // B
        (reference: 10.0, predicted: 200.0), // E
      ]);
      expect(result.total, 4);
      expect(result.zoneAFraction, closeTo(0.5, 1e-9));
      expect(result.abFraction, closeTo(0.75, 1e-9));
      expect(result.dangerousFraction, closeTo(0.25, 1e-9));
    });
  });
}
