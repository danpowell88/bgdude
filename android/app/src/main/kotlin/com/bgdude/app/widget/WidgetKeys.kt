package com.bgdude.app.widget

/**
 * Single source of truth for the home-widget SharedPreferences keys shared with the Dart
 * side (TASK-111). Must match `lib/widget/widget_keys.dart` exactly — a mismatch renders a
 * blank widget field with no compile error. A contract test asserts [ALL] equals the Dart
 * set.
 */
object WidgetKeys {
    const val BG_TEXT = "bg_text"
    const val TREND = "bg_trend"
    const val UNIT = "bg_unit"
    const val IOB = "iob_text"
    const val RANGE = "bg_range"
    const val CGM_EPOCH_MS = "cgm_epoch_ms"

    val ALL: Set<String> = setOf(BG_TEXT, TREND, UNIT, IOB, RANGE, CGM_EPOCH_MS)
}
