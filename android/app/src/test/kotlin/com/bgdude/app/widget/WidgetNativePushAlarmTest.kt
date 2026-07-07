package com.bgdude.app.widget

import android.app.AlarmManager
import android.app.Application
import android.appwidget.AppWidgetManager
import androidx.test.core.app.ApplicationProvider
import com.bgdude.app.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * TASK-236: `scheduleStalenessRenders` (TASK-177) armed a 10-minute repeating alarm from
 * `PumpService.onCreate` unconditionally, and `cancelStalenessRenders` was never called
 * from anywhere -- the alarm outlived every widget removal and kept waking the receiver
 * until reboot. Pins: the alarm arms on `BgWidgetProvider.onEnabled`, cancels on
 * `onDisabled`, and `scheduleStalenessRendersIfWidgetsExist` (what `PumpService.onCreate`
 * now calls) only arms when a widget instance actually exists.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WidgetNativePushAlarmTest {

    private val app get() = ApplicationProvider.getApplicationContext<Application>()
    private val alarmManager get() = app.getSystemService(AlarmManager::class.java)

    private fun installWidget(): Int =
        shadowOf(AppWidgetManager.getInstance(app))
            .createWidget(BgWidgetProvider::class.java, R.layout.bg_widget)

    @Test
    fun `onEnabled arms an inexact repeating alarm`() {
        BgWidgetProvider().onEnabled(app)

        val alarms = shadowOf(alarmManager).scheduledAlarms
        assertEquals(1, alarms.size)
        assertEquals(AlarmManager.ELAPSED_REALTIME, alarms.single().getType())
    }

    @Test
    fun `onDisabled cancels the alarm armed by onEnabled`() {
        BgWidgetProvider().onEnabled(app)
        assertTrue(shadowOf(alarmManager).scheduledAlarms.isNotEmpty())

        BgWidgetProvider().onDisabled(app)

        assertTrue(
            "the last widget being removed must cancel the staleness alarm, not "
                + "leave it running until reboot (the exact bug this task fixes)",
            shadowOf(alarmManager).scheduledAlarms.isEmpty(),
        )
    }

    @Test
    fun `scheduleStalenessRendersIfWidgetsExist arms nothing when no widget exists`() {
        WidgetNativePush.scheduleStalenessRendersIfWidgetsExist(app)

        assertTrue(shadowOf(alarmManager).scheduledAlarms.isEmpty())
    }

    @Test
    fun `scheduleStalenessRendersIfWidgetsExist arms the alarm once a widget exists`() {
        installWidget()

        WidgetNativePush.scheduleStalenessRendersIfWidgetsExist(app)

        assertEquals(1, shadowOf(alarmManager).scheduledAlarms.size)
    }

    @Test
    fun `hasWidgetInstances reflects whether any widget is installed`() {
        assertTrue(!WidgetNativePush.hasWidgetInstances(app))
        installWidget()
        assertTrue(WidgetNativePush.hasWidgetInstances(app))
    }
}
