package com.bgdude.app.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.bgdude.app.MainActivity
import com.bgdude.app.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing the current BG + trend arrow, IOB, and reading age.
 *
 * The Dart side ([lib/widget/home_widget_service.dart]) pushes pre-formatted display
 * strings through the home_widget plugin whenever a new pump snapshot arrives; this
 * provider only lays them into the RemoteViews. The two *time-dependent* pieces —
 * staleness and the "Xm ago" text — are recomputed here from the stored CGM epoch so
 * that system-triggered renders (resize, launcher restart, reboot) show the correct
 * age even if the Flutter side hasn't run since the last push. The formatting rules
 * mirror the pure Dart function in `lib/widget/bg_widget_format.dart`, which is the
 * unit-tested source of truth.
 *
 * Colouring: red below 70 mg/dL, green in range, orange above 180 mg/dL; everything
 * greys out once the reading is older than 15 minutes (or there is no reading).
 */
class BgWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val views = render(context, widgetData)
        for (widgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun render(context: Context, data: SharedPreferences): RemoteViews {
        val bgText = data.getString(KEY_BG_TEXT, null) ?: "--"
        val trendArrow = data.getString(KEY_TREND, null) ?: ""
        val unitLabel = data.getString(KEY_UNIT, null) ?: ""
        val iobText = data.getString(KEY_IOB, null) ?: "IOB --"
        val range = data.getString(KEY_RANGE, null) ?: RANGE_UNKNOWN

        // The epoch is written from Dart as an int; depending on magnitude the platform
        // channel stores it as Int or Long, so read through `all` and widen safely.
        val cgmEpochMs = (data.all[KEY_CGM_EPOCH_MS] as? Number)?.toLong()
        val ageMinutes = cgmEpochMs?.let {
            ((System.currentTimeMillis() - it) / 60_000L).coerceAtLeast(0)
        }
        val stale = ageMinutes == null || ageMinutes > STALE_AFTER_MINUTES

        val primaryColor = if (stale) {
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

        return RemoteViews(context.packageName, R.layout.bg_widget).apply {
            setTextViewText(R.id.bg_value, bgText)
            setTextViewText(R.id.bg_trend, trendArrow)
            setTextViewText(R.id.bg_unit, unitLabel)
            setTextViewText(R.id.iob_text, iobText)
            setTextViewText(R.id.updated_text, updatedText)
            setTextColor(R.id.bg_value, primaryColor)
            setTextColor(R.id.bg_trend, primaryColor)
            setTextColor(R.id.iob_text, if (stale) COLOR_STALE else COLOR_TEXT_SECONDARY)
            setTextColor(R.id.updated_text, if (stale) COLOR_STALE else COLOR_TEXT_TERTIARY)
            setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
        }
    }

    private companion object {
        // SharedPreferences keys — single source in WidgetKeys, matched to the Dart side
        // (lib/widget/widget_keys.dart) by a contract test (TASK-111).
        const val KEY_BG_TEXT = WidgetKeys.BG_TEXT
        const val KEY_TREND = WidgetKeys.TREND
        const val KEY_UNIT = WidgetKeys.UNIT
        const val KEY_IOB = WidgetKeys.IOB
        const val KEY_RANGE = WidgetKeys.RANGE
        const val KEY_CGM_EPOCH_MS = WidgetKeys.CGM_EPOCH_MS

        // Range tokens — must match BgRange.token in lib/widget/bg_widget_format.dart.
        const val RANGE_LOW = "low"
        const val RANGE_IN_RANGE = "inRange"
        const val RANGE_HIGH = "high"
        const val RANGE_UNKNOWN = "unknown"

        const val STALE_AFTER_MINUTES = 15L

        const val COLOR_LOW = 0xFFEF5350.toInt()
        const val COLOR_IN_RANGE = 0xFF66BB6A.toInt()
        const val COLOR_HIGH = 0xFFFFA726.toInt()
        const val COLOR_STALE = 0xFF9E9E9E.toInt()
        const val COLOR_TEXT_SECONDARY = 0xCCFFFFFF.toInt()
        const val COLOR_TEXT_TERTIARY = 0x99FFFFFF.toInt()
    }
}
