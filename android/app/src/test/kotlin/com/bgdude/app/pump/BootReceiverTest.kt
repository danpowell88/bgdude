package com.bgdude.app.pump

import android.Manifest
import android.app.Application
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/** TASK-186: TASK-12's boot-time restart, gated on the Android 12+ Bluetooth permission. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class BootReceiverTest {

    private val app get() = ApplicationProvider.getApplicationContext<Application>()

    @Test
    fun `without Bluetooth permission, boot does not start the pump service`() {
        BootReceiver().onReceive(app, Intent(Intent.ACTION_BOOT_COMPLETED))

        assertNull(shadowOf(app).nextStartedService)
    }

    @Test
    fun `with Bluetooth permission, boot starts the pump service with auto-reconnect`() {
        shadowOf(app).grantPermissions(Manifest.permission.BLUETOOTH_CONNECT)

        BootReceiver().onReceive(app, Intent(Intent.ACTION_BOOT_COMPLETED))

        val started = shadowOf(app).nextStartedService
        assertEquals(PumpService::class.java.name, started?.component?.className)
        assertEquals(true, started?.getBooleanExtra(PumpService.EXTRA_AUTO_RECONNECT, false))
    }

    @Test
    fun `ignores an unrelated action`() {
        BootReceiver().onReceive(app, Intent("some.other.action"))

        assertNull(shadowOf(app).nextStartedService)
    }
}
