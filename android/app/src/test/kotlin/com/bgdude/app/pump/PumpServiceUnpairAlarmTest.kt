package com.bgdude.app.pump

import android.Manifest
import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import androidx.test.core.app.ApplicationProvider
import com.bgdude.app.R
import com.bgdude.app.widget.BgWidgetProvider
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * TASK-284: TASK-236 made [PumpService.unpair] cancel the widget staleness alarm
 * unconditionally, which reintroduces the TASK-177 frozen-green-widget bug for the
 * unpair path specifically -- a widget can still be placed on the home screen with no
 * new pump data ever coming again, and grey-out is driven entirely by this periodic
 * re-render. Pins: unpair leaves an already-armed alarm alone.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PumpServiceUnpairAlarmTest {

    private val app get() = ApplicationProvider.getApplicationContext<android.app.Application>()
    private val alarmManager get() = app.getSystemService(AlarmManager::class.java)

    @Test
    fun `unpair with a widget still placed leaves the staleness alarm armed`() {
        // A widget instance exists, so onCreate's scheduleStalenessRendersIfWidgetsExist
        // arms the alarm.
        shadowOf(AppWidgetManager.getInstance(app))
            .createWidget(BgWidgetProvider::class.java, R.layout.bg_widget)
        shadowOf(app).grantPermissions(Manifest.permission.BLUETOOTH_CONNECT)
        val controller = Robolectric.buildService(PumpService::class.java).create()
        val service = controller.get()
        assertTrue(
            "precondition: the alarm should be armed once a widget exists",
            shadowOf(alarmManager).scheduledAlarms.isNotEmpty(),
        )

        service.unpair()

        assertTrue(
            "unpair() must not cancel the staleness alarm while a widget is still "
                + "placed -- that would freeze it at its last live-looking value "
                + "forever instead of greying out (the TASK-177 bug, reintroduced)",
            shadowOf(alarmManager).scheduledAlarms.isNotEmpty(),
        )
        controller.destroy()
    }
}
