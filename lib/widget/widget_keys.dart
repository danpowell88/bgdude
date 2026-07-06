/// Cross-language contract for the home-widget SharedPreferences keys (TASK-111). These
/// must match the Kotlin `BgWidgetProvider` KEY_* constants exactly — a mismatch renders a
/// blank widget field with no compile-time error. Defined once and asserted equal to the
/// Kotlin side by a contract test.
library;

class WidgetKeys {
  static const String bgText = 'bg_text';
  static const String trend = 'bg_trend';
  static const String unit = 'bg_unit';
  static const String iob = 'iob_text';
  static const String range = 'bg_range';
  static const String cgmEpochMs = 'cgm_epoch_ms';

  /// The full set, for the contract test.
  static const Set<String> all = {bgText, trend, unit, iob, range, cgmEpochMs};
}
