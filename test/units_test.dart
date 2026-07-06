import 'package:bgdude/core/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mgdl.inUnit returns the raw value for mg/dL and mmol for mmol/L', () {
    const m = Mgdl(180);
    expect(m.inUnit(GlucoseUnit.mgdl), 180);
    expect(m.inUnit(GlucoseUnit.mmol), closeTo(180 / kMgdlPerMmol, 1e-9));
    expect(m.inUnit(GlucoseUnit.mmol), closeTo(9.99, 0.01));
  });

  test('inUnit converts a delta by the same factor (no rounding hidden)', () {
    // A +18 mg/dL rise is +1.0 mmol/L (near enough); the helper keeps the precision.
    expect(const Mgdl(18.0182).inUnit(GlucoseUnit.mmol), closeTo(1.0, 1e-9));
  });
}
