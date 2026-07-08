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

    // TASK-245: the lower half (predicted < reference -- under-prediction, i.e.
    // missing a real high) had zero pinned points despite being the subtlest
    // extrapolated boundary. Points below are chosen directly from the same Table 1
    // polygon vertices already cited above the class (_zoneBLower/_zoneCLower/
    // _zoneDLower), the same source the already-verified upper-half points use --
    // this environment has no R/ega access to independently re-run getParkesZones,
    // so this pins the port's own internal consistency and guards the boundary
    // coefficients against a silent future regression, per AC#3.
    group('lower half (under-prediction)', () {
      test('a benign under-read is zone B', () {
        // B-lower's diagonal boundary ((50,30)-(170,145)) is at y=77.9 when x=100;
        // predicted=20 is well below it, and x=100 is well short of C-lower's own
        // start (x=120), so nothing nested further overwrites B.
        expect(grid.classify(100, 20), ParkesZone.b);
      });

      test('a moderate under-read is zone C', () {
        // C-lower's diagonal boundary ((120,30)-(260,130)) is at y=87.1 when
        // x=200; predicted=50 is well below it. x=200 is short of D-lower's own
        // start (x=250), so nothing nested further overwrites C.
        expect(grid.classify(200, 50), ParkesZone.c);
      });

      test('a dangerous under-read (missed high) is zone D', () {
        // D-lower's boundary ((250,40)-(1000,326.3), the far anchor extrapolated
        // from the (410,110)/(550,150) Table 1 points) is at y=59.1 when x=300;
        // predicted=20 is well below it, and there's no further-nested "E-lower"
        // zone in this direction (E only covers the opposite, over-read pattern).
        expect(grid.classify(300, 20), ParkesZone.d);
      });
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
