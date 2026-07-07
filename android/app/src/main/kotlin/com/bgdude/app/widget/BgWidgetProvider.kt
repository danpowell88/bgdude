package com.bgdude.app.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.bgdude.app.MainActivity
import com.bgdude.app.R
import com.bgdude.app.pump.SafeCallbacks
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing the current BG + trend arrow, IOB, and reading age.
 *
 * Display strings arrive from EITHER the Dart side (home_widget plugin pushes on each
 * snapshot) or, since TASK-177, natively from [WidgetNativePush] so the widget stays
 * honest when the Flutter engine is dead. The time-dependent pieces — staleness and
 * the "Xm ago" text — are recomputed on every render by [WidgetRenderModel] (the
 * JVM-tested mirror of `lib/widget/bg_widget_format.dart`), and a periodic alarm
 * fires [WidgetNativePush.ACTION_REFRESH] so grey-out happens even with no new data.
 *
 * Colouring: red below 70 mg/dL, green in range, orange above 180 mg/dL; everything
 * greys out once the reading is older than 15 minutes (or there is no reading).
 */
class BgWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        // TASK-196: BgWidgetProvider has no android:process isolation, so it shares
        // PumpService's process — an uncaught exception escaping onReceive kills the
        // BLE link and the native urgent-low backstop along with the widget. This is
        // the outermost backstop; render()/updateAppWidget() below are also guarded
        // individually for better diagnostics, but this catches anything else too
        // (e.g. a future throw in the superclass's own onReceive/onUpdate).
        SafeCallbacks.run("BgWidgetProvider.onReceive") {
            // TASK-177: the staleness alarm / native push re-render path.
            if (intent.action == WidgetNativePush.ACTION_REFRESH) {
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(
                    ComponentName(context, BgWidgetProvider::class.java))
                if (ids.isNotEmpty()) {
                    val data = context.getSharedPreferences(
                        WidgetNativePush.PREFS_NAME, Context.MODE_PRIVATE)
                    onUpdate(context, manager, ids, data)
                }
            } else {
                super.onReceive(context, intent)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val views = renderSafely(context, widgetData)
        for (widgetId in appWidgetIds) {
            // A per-widget updateAppWidget() call is its own throw vector
            // (TransactionTooLarge, resource failures) independent of what render()
            // produced — guarded per-id so one bad widget instance can't block the
            // others from updating.
            SafeCallbacks.run("BgWidgetProvider.updateAppWidget") {
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }
    }

    /**
     * Renders the widget, guarded (TASK-196/AC#1): a bad-typed prefs value
     * (`SharedPreferences.getString` throws `ClassCastException` if a non-String was
     * ever stored under that key), a `RemoteViews`/launch-intent construction
     * failure, or anything else in [render] falls back to a minimal static display
     * instead of propagating — better a stale-looking "--" than a dead pump service.
     */
    private fun renderSafely(context: Context, data: SharedPreferences): RemoteViews =
        SafeCallbacks.run("BgWidgetProvider.render", safeFallbackViews(context)) {
            render(context, data)
        }

    /** A minimal RemoteViews built from fixed strings only — no prefs, no dynamic
     * data — so it cannot hit the same failure modes [render] guards against. */
    private fun safeFallbackViews(context: Context): RemoteViews =
        RemoteViews(context.packageName, R.layout.bg_widget).apply {
            setTextViewText(R.id.bg_value, "--")
            setTextViewText(R.id.bg_trend, "")
            setTextViewText(R.id.bg_unit, "")
            setTextViewText(R.id.iob_text, "IOB --")
            setTextViewText(R.id.updated_text, "")
        }

    private fun render(context: Context, data: SharedPreferences): RemoteViews {
        val bgText = data.getString(WidgetKeys.BG_TEXT, null) ?: "--"
        val trendArrow = data.getString(WidgetKeys.TREND, null) ?: ""
        val unitLabel = data.getString(WidgetKeys.UNIT, null) ?: ""
        val iobText = data.getString(WidgetKeys.IOB, null) ?: "IOB --"
        val range = data.getString(WidgetKeys.RANGE, null)

        // The epoch is written from Dart as an int; depending on magnitude the platform
        // channel stores it as Int or Long, so read through `all` and widen safely.
        val cgmEpochMs = (data.all[WidgetKeys.CGM_EPOCH_MS] as? Number)?.toLong()
        val rendered = WidgetRenderModel.render(
            range = range,
            cgmEpochMs = cgmEpochMs,
            nowMs = System.currentTimeMillis(),
        )

        return RemoteViews(context.packageName, R.layout.bg_widget).apply {
            setTextViewText(R.id.bg_value, bgText)
            setTextViewText(R.id.bg_trend, trendArrow)
            setTextViewText(R.id.bg_unit, unitLabel)
            setTextViewText(R.id.iob_text, iobText)
            setTextViewText(R.id.updated_text, rendered.updatedText)
            setTextColor(R.id.bg_value, rendered.primaryColor)
            setTextColor(R.id.bg_trend, rendered.primaryColor)
            setTextColor(R.id.iob_text, rendered.secondaryColor)
            setTextColor(R.id.updated_text, rendered.tertiaryColor)
            setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
        }
    }
}
