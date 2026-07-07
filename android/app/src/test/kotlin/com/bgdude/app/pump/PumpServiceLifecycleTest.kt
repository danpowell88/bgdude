package com.bgdude.app.pump

import android.Manifest
import android.app.NotificationManager
import android.app.Service
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * TASK-186: the notification channels must exist before [Service.startForeground] is ever
 * called, or Android throws — [PumpService.onCreate] creates them, which the real Android
 * lifecycle always runs before [PumpService.onStartCommand]. Also covers the Android 12+
 * Bluetooth-permission gate on actually going foreground.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PumpServiceLifecycleTest {

    @Test
    fun `both notification channels exist right after onCreate, before any startCommand`() {
        val controller = Robolectric.buildService(PumpService::class.java).create()
        val nm = ApplicationProvider.getApplicationContext<android.content.Context>()
            .getSystemService(NotificationManager::class.java)

        assertNotNull(nm.getNotificationChannel("pump_connection"))
        assertNotNull(nm.getNotificationChannel("urgent_low_backstop"))

        controller.destroy()
    }

    @Test
    fun `without Bluetooth permission, onStartCommand never goes foreground`() {
        val controller = Robolectric.buildService(PumpService::class.java).create()
        val service = controller.get()

        controller.startCommand(0, 0)

        assertNull(shadowOf(service).lastForegroundNotification)
        controller.destroy()
    }

    @Test
    fun `with Bluetooth permission granted, onStartCommand goes foreground`() {
        shadowOf(ApplicationProvider.getApplicationContext<android.app.Application>())
            .grantPermissions(Manifest.permission.BLUETOOTH_CONNECT)
        val controller = Robolectric.buildService(PumpService::class.java).create()
        val service = controller.get()

        controller.startCommand(0, 0)

        assertNotNull(shadowOf(service).lastForegroundNotification)
        controller.destroy()
    }
}
