package com.bgdude.app.pump

import android.os.Looper
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
 * TASK-267: a Robolectric repro for the crash found while testing the concurrency fix --
 * pumpx2's TandemBluetoothHandler constructs its own android.os.Handler on whatever thread
 * first calls getInstance(), which requires Looper.prepare() on that thread. The DEFAULT
 * pairingExecutor (a plain Executors.newSingleThreadExecutor()) had none, so every real
 * startScan/submitPairingCode/unpair call crashed the first time -- real Android framework
 * behaviour (Handler's no-arg constructor), not a test-only artifact. This exercises the
 * REAL default executor (not a test double), through the real PumpHostApiImpl -> PumpService
 * -> PumpCommHandler.start() -> TandemBluetoothHandler.getInstance() path.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PumpHostApiImplLooperTest {

    @Test
    fun `startScan on the real default pairing executor does not crash constructing TandemBluetoothHandler`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val controller = Robolectric.buildService(PumpService::class.java).create()
        val service = controller.get()

        val impl = PumpHostApiImpl(context)
        impl.bind(service)

        var result: Result<Unit>? = null
        impl.startScan(null) { result = it }

        // The pairing executor's background thread runs startScan and then posts the
        // callback onto the main handler; Robolectric's main looper is paused by default
        // and needs an explicit idle() to run posted work. Poll briefly since the
        // background thread's own completion isn't otherwise observable from here.
        val deadline = System.currentTimeMillis() + 5000
        while (result == null && System.currentTimeMillis() < deadline) {
            shadowOf(Looper.getMainLooper()).idle()
            Thread.sleep(20)
        }

        assertNotNull("startScan callback never ran", result)
        assertNull("startScan crashed constructing TandemBluetoothHandler: " +
            "${result?.exceptionOrNull()}", result?.exceptionOrNull())

        impl.shutdown()
        controller.destroy()
    }
}
