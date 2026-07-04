/// Glucose unit handling.
///
/// All glucose is stored internally in **mg/dL** (the raw unit the Tandem pump and
/// Dexcom sensor report). Display defaults to **mmol/L** (Australia). The conversion
/// factor is exact by definition: 1 mmol/L = 18.0182 mg/dL for glucose (molar mass
/// 180.156 g/mol), but the field convention rounds to 18.0.
library;

/// mg/dL per mmol/L for glucose. The clinical/field-standard factor is 18.0182;
/// most CGM apps use 18.0. We keep the precise value for internal math and only
/// round at the display boundary.
const double kMgdlPerMmol = 18.0182;

enum GlucoseUnit {
  mgdl,
  mmol;

  String get label => switch (this) {
        GlucoseUnit.mgdl => 'mg/dL',
        GlucoseUnit.mmol => 'mmol/L',
      };
}

/// A glucose value, always carried internally as mg/dL.
extension type const Mgdl(double value) {
  double get mmol => value / kMgdlPerMmol;

  /// Render in the user's chosen unit with sensible precision
  /// (whole numbers for mg/dL, one decimal for mmol/L).
  String display(GlucoseUnit unit) => switch (unit) {
        GlucoseUnit.mgdl => value.round().toString(),
        GlucoseUnit.mmol => mmol.toStringAsFixed(1),
      };

  static Mgdl fromMmol(double mmol) => Mgdl(mmol * kMgdlPerMmol);
}

/// Standard clinical thresholds, expressed in mg/dL (the storage unit).
/// Source: International Consensus on Time in Range (Diabetes Care 2019).
class GlucoseThresholds {
  /// Level 2 hypo (very low).
  static const double veryLow = 54;

  /// Level 1 hypo / lower bound of range.
  static const double low = 70;

  /// Upper bound of range.
  static const double high = 180;

  /// Level 2 hyper (very high).
  static const double veryHigh = 250;

  const GlucoseThresholds._();
}
