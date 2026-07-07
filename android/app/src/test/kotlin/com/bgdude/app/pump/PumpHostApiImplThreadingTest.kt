package com.bgdude.app.pump

import android.os.Handler
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * TASK-205: submitPairingCode/startScan hit pumpx2's SharedPreferences-backed
 * PumpState synchronously — a minor ANR risk when run inline on the main thread,
 * which is where Flutter dispatches platform-channel method calls. Verifies the
 * work actually runs on a different thread, and the callback still correctly
 * marshals back.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PumpHostApiImplThreadingTest {

    /** Wraps a real executor so the test can observe which thread ran the work. */
    private class RecordingExecutor(
        private val delegate: ExecutorService = Executors.newSingleThreadExecutor(),
    ) : ExecutorService by delegate {
        @Volatile var lastExecuteThread: Thread? = null

        override fun execute(command: Runnable) {
            delegate.execute {
                lastExecuteThread = Thread.currentThread()
                command.run()
            }
        }
    }

    @Test
    fun `submitPairingCode runs off the calling thread and still marshals the callback back`() {
        val executor = RecordingExecutor()
        val impl = PumpHostApiImpl(
            ApplicationProvider.getApplicationContext(),
            pairingExecutor = executor,
            mainHandler = Handler(Looper.getMainLooper()),
        )
        val callingThread = Thread.currentThread()

        var callbackResult: Result<Unit>? = null
        impl.submitPairingCode("123456", PairingCodeType.SHORT_6CHAR) { result ->
            callbackResult = result
        }

        // Wait for the executor's single queued task (which ends by posting the
        // callback onto the main handler) to actually finish running.
        executor.shutdown()
        assertTrue(executor.awaitTermination(2, TimeUnit.SECONDS))
        // Now flush the main looper's queue so the posted callback actually runs —
        // Robolectric's main looper is paused by default and needs an explicit idle.
        shadowOf(Looper.getMainLooper()).idle()

        assertNotEquals(callingThread, executor.lastExecuteThread)
        assertNotNull(callbackResult)
        assertTrue(callbackResult!!.isSuccess)
    }

    @Test
    fun `startScan runs off the calling thread and still marshals the callback back`() {
        val executor = RecordingExecutor()
        val impl = PumpHostApiImpl(
            ApplicationProvider.getApplicationContext(),
            pairingExecutor = executor,
            mainHandler = Handler(Looper.getMainLooper()),
        )
        val callingThread = Thread.currentThread()

        var callbackResult: Result<Unit>? = null
        impl.startScan(null) { result -> callbackResult = result }

        executor.shutdown()
        assertTrue(executor.awaitTermination(2, TimeUnit.SECONDS))
        shadowOf(Looper.getMainLooper()).idle()

        assertNotEquals(callingThread, executor.lastExecuteThread)
        assertNotNull(callbackResult)
        assertTrue(callbackResult!!.isSuccess)
    }
}
