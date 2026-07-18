package com.bgdude.app.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import androidx.core.content.edit
import com.bgdude.app.pump.MutableSnapshot

/**
 * TASK-177: widget updates that do NOT depend on a live Flutter engine. The Dart
 * side used to be the only writer/re-renderer — if the OS killed the engine while
 * the pump service kept the BLE link, the widget froze green with a stuck "3m ago".
 *
 *  * [push] writes fresh display fields straight from the native snapshot into the
 *    home_widget SharedPreferences and triggers a render.
 *  * [scheduleStalenessRenders] arms an inexact repeating alarm so the provider
 *    re-renders (and greys out past the threshold) even with NO new data at all.
 */
object WidgetNativePush {

    /** Must match HomeWidgetPlugin.PREFERENCES (es.antonborri.home_widget). */
    const val PREFS_NAME = "HomeWidgetPreferences"

    /** Custom refresh action handled by [BgWidgetProvider.onReceive]. */
    const val ACTION_REFRESH = "com.bgdude.app.widget.REFRESH"

    /** Re-render cadence: half the 15-min staleness threshold, inexact. */
    private const val RENDER_INTERVAL_MS = 10 * 60 * 1000L

    fun push(context: Context, snapshot: MutableSnapshot) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        // The user's display unit is whatever Dart last stored; default mmol.
        val unitLabel = prefs.getString(WidgetKeys.UNIT, null)
        val fields = WidgetRenderModel.fields(
            cgmMgdl = snapshot.cgmMgdl,
            trend = snapshot.cgmTrend,
            iobUnits = snapshot.iobUnits,
            unitLabel = unitLabel,
        )
        prefs.edit {
            putString(WidgetKeys.BG_TEXT, fields.bgText)
            putString(WidgetKeys.TREND, fields.trendArrow)
            putString(WidgetKeys.IOB, fields.iobText)
            putString(WidgetKeys.RANGE, fields.range)
            val epoch = snapshot.cgmTimestampEpochMs
            if (epoch != null) putLong(WidgetKeys.CGM_EPOCH_MS, epoch)
        }
        requestRender(context)
    }

    /** Broadcast the custom refresh so the provider re-renders from stored data. */
    fun requestRender(context: Context) {
        context.sendBroadcast(
            Intent(context, BgWidgetProvider::class.java).setAction(ACTION_REFRESH)
        )
    }

    /** TASK-236: whether at least one instance of the widget is currently placed. */
    fun hasWidgetInstances(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        return manager
            .getAppWidgetIds(ComponentName(context, BgWidgetProvider::class.java))
            .isNotEmpty()
    }

    fun scheduleStalenessRenders(context: Context) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarm.setInexactRepeating(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + RENDER_INTERVAL_MS,
            RENDER_INTERVAL_MS,
            renderIntent(context),
        )
    }

    /**
     * TASK-236: [PumpService.onCreate] calls this (not [scheduleStalenessRenders]
     * directly) so the alarm is re-armed reliably on every service start/reboot --
     * matching the reliability [scheduleStalenessRenders] was originally added for
     * (TASK-177: staleness grey-out survives engine death) -- but only when a widget
     * instance actually exists to benefit from it. [BgWidgetProvider.onEnabled] also
     * arms directly, covering a widget added while the service is already running and
     * won't restart soon.
     */
    fun scheduleStalenessRendersIfWidgetsExist(context: Context) {
        if (hasWidgetInstances(context)) scheduleStalenessRenders(context)
    }

    fun cancelStalenessRenders(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
            .cancel(renderIntent(context))
    }

    private fun renderIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            4177, // arbitrary stable request code for this alarm
            Intent(context, BgWidgetProvider::class.java).setAction(ACTION_REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}
