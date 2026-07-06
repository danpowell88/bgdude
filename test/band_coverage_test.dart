import 'package:bgdude/analytics/band_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

/// TASK-56 AC#1: 7-day band coverage from reconciled predictions.
void main() {
  ({double? actual, double lower, double upper}) p(double? a, double lo, double hi) =>
      (actual: a, lower: lo, upper: hi);

  test('counts only reconciled predictions and those inside the band', () {
    final c = computeBandCoverage([
      p(120, 100, 140), // in
      p(160, 100, 140), // out (above)
      p(90, 100, 140), // out (below)
      p(130, 100, 140), // in
      p(null, 100, 140), // not reconciled → ignored
    ]);
    expect(c.total, 4);
    expect(c.covered, 2);
    expect(c.fraction, closeTo(0.5, 1e-9));
    expect(c.hasData, isTrue);
  });

  test('band edges are inclusive', () {
    final c = computeBandCoverage([p(100, 100, 140), p(140, 100, 140)]);
    expect(c.covered, 2);
  });

  test('no reconciled data → no coverage', () {
    final c = computeBandCoverage([p(null, 100, 140)]);
    expect(c.hasData, isFalse);
    expect(c.fraction, 0);
  });
}
