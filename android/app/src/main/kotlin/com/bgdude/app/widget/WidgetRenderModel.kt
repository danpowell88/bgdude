package com.bgdude.app.widget

import kotlin.math.roundToInt

/**
 * Pure widget render/formatting decisions (TASK-177), extracted from the provider so
 * they are JVM-testable without Robolectric. Mirrors the unit-tested Dart source of
 * truth in `lib/widget/bg_widget_format.dart` — colours by range, grey-out past 15 min
 * (or with no reading), and the same display strings — so a NATIVE push (from
 * PumpService, with the Flutter engine possibly dead) renders identically to a Dart one.
 */
object WidgetRenderModel {

    const val STALE_AFTER_MINUTES = 15L

    // Range tokens — must match BgRange.token in lib/widget/bg_widget_format.dart.
    const val RANGE_LOW = "low"
    const val RANGE_IN_RANGE = "inRange"
    const val RANGE_HIGH = "high"
    const val RANGE_UNKNOWN = "unknown"

    const val COLOR_LOW = 0xFFEF5350.toInt()
    const val COLOR_IN_RANGE = 0xFF66BB6A.toInt()
    const val COLOR_HIGH = 0xFFFFA726.toInt()
    const val COLOR_STALE = 0xFF9E9E9E.toInt()
    const val COLOR_TEXT_SECONDARY = 0xCCFFFFFF.toInt()
    const val COLOR_TEXT_TERTIARY = 0x99FFFFFF.toInt()

    /** mg/dL per mmol/L — the precise factor `lib/core/units.dart` uses. */
    private const val MGDL_PER_MMOL = 18.0182

    data class Rendered(
        val stale: Boolean,
        val primaryColor: Int,
        val secondaryColor: Int,
        val tertiaryColor: Int,
        val updatedText: String,
    )

    /** The time-dependent render decision (staleness, colours, age line). */
    fun render(range: String?, cgmEpochMs: Long?, nowMs: Long): Rendered {
        val ageMinutes = cgmEpochMs?.let { ((nowMs - it) / 60_000L).coerceAtLeast(0) }
        val stale = ageMinutes == null || ageMinutes > STALE_AFTER_MINUTES

        val primary = if (stale) {
            COLOR_STALE
        } else {
            when (range) {
                RANGE_LOW -> COLOR_LOW
                RANGE_HIGH -> COLOR_HIGH
                RANGE_IN_RANGE -> COLOR_IN_RANGE
                else -> COLOR_STALE
            }
        }

        val agePart = when {
            ageMinutes == null -> null
            ageMinutes <= 0L -> "just now"
            ageMinutes < 60L -> "${ageMinutes}m ago"
            else -> "${ageMinutes / 60}h ago"
        }
        val updatedText = when {
            agePart == null -> "no data"
            stale -> "Stale · $agePart"
            else -> agePart
        }

        return Rendered(
            stale = stale,
            primaryColor = primary,
            secondaryColor = if (stale) COLOR_STALE else COLOR_TEXT_SECONDARY,
            tertiaryColor = if (stale) COLOR_STALE else COLOR_TEXT_TERTIARY,
            updatedText = updatedText,
        )
    }

    data class Fields(
        val bgText: String,
        val trendArrow: String,
        val iobText: String,
        val range: String,
    )

    /**
     * Format the display fields from a raw snapshot (native push path). [unitLabel]
     * is the user's stored display unit ('mg/dL' | 'mmol/L'; anything else falls back
     * to mmol, matching the app default).
     */
    fun fields(cgmMgdl: Int?, trend: String?, iobUnits: Double?, unitLabel: String?): Fields {
        val bgText = when {
            cgmMgdl == null -> "--"
            unitLabel == "mg/dL" -> cgmMgdl.toString()
            else -> String.format(java.util.Locale.US, "%.1f", cgmMgdl / MGDL_PER_MMOL)
        }
        val arrow = if (cgmMgdl == null) "" else when (trend) {
            "doubleUp" -> "⇈"
            "singleUp" -> "↑"
            "fortyFiveUp" -> "↗"
            "flat" -> "→"
            "fortyFiveDown" -> "↘"
            "singleDown" -> "↓"
            "doubleDown" -> "⇊"
            else -> ""
        }
        val iobText = if (iobUnits == null) {
            "IOB --"
        } else {
            "IOB ${String.format(java.util.Locale.US, "%.1f", iobUnits)} U"
        }
        val range = when {
            cgmMgdl == null -> RANGE_UNKNOWN
            cgmMgdl < 70 -> RANGE_LOW
            cgmMgdl > 180 -> RANGE_HIGH
            else -> RANGE_IN_RANGE
        }
        return Fields(bgText = bgText, trendArrow = arrow, iobText = iobText, range = range)
    }

    /** Round-trip helper kept for parity with Dart's whole-number mg/dL display. */
    fun mgdlDisplay(mgdl: Double): String = mgdl.roundToInt().toString()
}
