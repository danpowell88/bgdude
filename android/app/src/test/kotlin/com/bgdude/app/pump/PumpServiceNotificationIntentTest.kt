package com.bgdude.app.pump

import android.Manifest
import android.app.Application
import android.app.NotificationManager
import android.app.PendingIntent
import androidx.test.core.app.ApplicationProvider
import com.bgdude.app.MainActivity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * TASK-203: tapping the ongoing connection notification, or the urgent-low
 * backstop, must open the app instead of doing nothing — the backstop exists
 * specifically for when the Flutter UI is dead, so a tap has to relaunch it.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PumpServiceNotificationIntentTest {

    /** TASK-263: `assertNotNull(contentIntent)` alone wouldn't catch a regression to
     *  `FLAG_MUTABLE` (crashes on API 31+) or an intent pointed at the wrong Activity --
     *  both are directly inspectable via Robolectric's PendingIntent shadow. */
    private fun assertOpensMainActivityImmutably(intent: PendingIntent) {
        val shadow = shadowOf(intent)
        assertTrue("contentIntent must be FLAG_IMMUTABLE (required on API 31+ for a "
            + "PendingIntent the app itself never mutates)", shadow.isImmutable)
        assertEquals("contentIntent must target MainActivity so tapping it relaunches "
            + "the app", MainActivity::class.java.name,
            shadow.savedIntent.component?.className)
    }

    @Test
    fun `the ongoing connection notification has a contentIntent`() {
        shadowOf(ApplicationProvider.getApplicationContext<Application>())
            .grantPermissions(Manifest.permission.BLUETOOTH_CONNECT)
        val controller = Robolectric.buildService(PumpService::class.java).create()
        val service = controller.get()

        controller.startCommand(0, 0)

        val notification = shadowOf(service).lastForegroundNotification
        assertNotNull(notification)
        assertNotNull(notification!!.contentIntent)
        assertOpensMainActivityImmutably(notification.contentIntent)
        controller.destroy()
    }

    @Test
    fun `the urgent-low backstop notification has a contentIntent`() {
        val app = ApplicationProvider.getApplicationContext<Application>()
        shadowOf(app).grantPermissions(Manifest.permission.BLUETOOTH_CONNECT)
        val controller = Robolectric.buildService(PumpService::class.java).create()
        val service = controller.get()

        service.onSnapshotUpdated(MutableSnapshot().apply { cgmMgdl = 40 })

        val nm = app.getSystemService(NotificationManager::class.java)
        val posted = shadowOf(nm).getNotification(43)
        assertNotNull("expected the urgent-low notification (id 43) to have posted", posted)
        assertNotNull(posted.contentIntent)
        assertOpensMainActivityImmutably(posted.contentIntent)

        controller.destroy()
    }
}
