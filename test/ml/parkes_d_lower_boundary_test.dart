/// The Parkes Type 1 D-lower boundary sits where Table 1 says it does (issue #381).
///
/// The `ega` R package this file was ported from extrapolates that edge from (410, 110),
/// which is not on the line its own slope is defined from. The boundary therefore drifted
/// progressively above the published one — ~0.8 mg/dL too high at a reference of 300,
/// ~4.5 too high at 550 — reporting pairs as zone D that the grid puts in zone C.
///
/// These cases are taken from the measured table in the issue, and every one of them
/// fails against the old anchor. They are the reason to trust the fix.
library;

import 'package:bgdude/ml/parkes_error_grid.dart';
import 'package:flutter_test/flutter_test.dart';

/// Table 1's Type 1 D/C boundary: the line through (250, 40) and (550, 150).
double _publishedDLower(double reference) =>
    40 + (150 - 40) / (550 - 250) * (reference - 250);

void main() {
  const grid = ParkesErrorGrid();

  group('the D-lower edge follows Table 1', () {
    // (reference, published boundary) from the issue's measured table.
    const cases = <(double, double)>[
      (300, 58.33),
      (400, 95.00),
      (450, 113.33),
      (500, 131.67),
      (550, 150.00),
    ];

    for (final (reference, boundary) in cases) {
      test('at reference $reference the boundary is ~$boundary', () {
        // Just BELOW the published line is zone D (further from the diagonal).
        expect(grid.classify(reference, boundary - 0.5), ParkesZone.d,
            reason: 'below the boundary should be D');

        // Just ABOVE it is zone C. This is the assertion the old anchor failed:
        // its edge sat up to 4.5 mg/dL higher, so this point was still called D.
        expect(grid.classify(reference, boundary + 0.5), ParkesZone.c,
            reason: 'above the boundary should be C, not D');
      });
    }
  });

  test('the boundary is a straight line of the published slope, not merely offset', () {
    // The original error grew with the reference value because the SLOPE was wrong.
    // Checking two widely separated points pins the slope, not just an intercept.
    for (final reference in [300.0, 400.0, 500.0, 550.0]) {
      final boundary = _publishedDLower(reference);
      expect(grid.classify(reference, boundary + 0.5), ParkesZone.c,
          reason: 'reference $reference');
      expect(grid.classify(reference, boundary - 0.5), ParkesZone.d,
          reason: 'reference $reference');
    }
  });

  test('(410, 110) — the bad anchor — is NOT treated as on the boundary', () {
    // The line through (250, 40) reaches only 98.67 at x=410, so 110 is comfortably
    // above the D/C edge and must classify as C. Under the old anchor this point sat
    // exactly ON the boundary, which is how the bug hid.
    expect(_publishedDLower(410), closeTo(98.67, 0.01));
    expect(grid.classify(410, 110), ParkesZone.c);
  });

  test('the vertex at (250, 40) still bounds the zone', () {
    // The fix moves the far end of the edge; it must not move the near end.
    expect(grid.classify(250, 39), ParkesZone.d);
    expect(grid.classify(250, 41), ParkesZone.c);
  });

  test('a perfect prediction is still zone A', () {
    // Guards against the polygon edit swallowing the diagonal.
    for (final v in [80.0, 120.0, 250.0, 400.0, 550.0]) {
      expect(grid.classify(v, v), ParkesZone.a, reason: '$v');
    }
  });

  test('the other zones are unaffected by the D-lower change', () {
    // Only Type 1 D-lower was wrong; a regression elsewhere would show here.
    // Dangerously high prediction for a low reference — zone E.
    expect(grid.classify(40, 300), ParkesZone.e);
    // Upper-side D: a real high read as near-normal.
    expect(grid.classify(60, 250), ParkesZone.d);
    // C-lower's own (260, 130) vertex still separates C from B — the polygon this
    // fix was modelled on must be untouched.
    expect(grid.classify(260, 129), ParkesZone.c);
    expect(grid.classify(260, 131), ParkesZone.b);
    // And at reference 260 the corrected D edge sits at ~43.7, so the D/C split is
    // there rather than up at 130.
    expect(grid.classify(260, 43), ParkesZone.d);
    expect(grid.classify(260, 45), ParkesZone.c);
  });
}
