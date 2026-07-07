package com.bgdude.app.pump

import android.os.Handler
import android.os.HandlerThread
import androidx.test.core.app.ApplicationProvider
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * TASK-267: start() runs on PumpHostApiImpl's off-main pairing executor while
 * destroy()/onDestroy run on the main thread -- a start racing a destroy must never
 * leave a live scanning handler orphaned with the service believing it's torn down.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PumpCommHandlerConcurrencyTest {

    private class RecordingListener : PumpCommHandler.Listener {
        override fun onState(state: NativeConnectionState) {}
        override fun onSnapshotUpdated(snapshot: MutableSnapshot) {}
        override fun onPairingCodeRequired(type: PairingCodeType) {}
        override fun onCriticalError(message: String) {}
    }

    /** Runs [start]/[destroy] concurrently from two threads released at the same
     *  instant, repeated many times to make either interleaving likely to occur at
     *  least once across the run. */
    @Test
    fun `a concurrent start and destroy never leaves an orphaned live handler`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()

        repeat(20) {
            val handler = PumpCommHandler(context, RecordingListener())
            val release = CountDownLatch(1)
            val done = CountDownLatch(2)

            // start() must run on a thread with a prepared Looper -- pumpx2's
            // TandemBluetoothHandler constructs its own android.os.Handler on whatever
            // thread first calls getInstance() (see PumpHostApiImplLooperTest), matching
            // how it's actually dispatched in production (PumpHostApiImpl's
            // HandlerThread-backed pairing executor).
            val startHandlerThread = HandlerThread("test-pairing").apply { start() }
            val startHandler = Handler(startHandlerThread.looper)

            startHandler.post {
                release.await()
                handler.start(null)
                done.countDown()
            }
            val destroyThread = Thread {
                release.await()
                handler.destroy()
                done.countDown()
            }
            destroyThread.start()
            release.countDown()
            assertTrue("start/destroy did not complete", done.await(5, TimeUnit.SECONDS))
            startHandlerThread.quitSafely()

            // Whichever thread's synchronized block ran second sees the other's effect:
            // destroy() either stops a handler start() just set (bluetoothHandler ends up
            // null again) or start() sees destroyed=true and never assigns bluetoothHandler
            // at all. Either way, the post-race state must be fully torn down.
            assertTrue("destroy() must have run", handler.destroyed)
            assertNull(
                "a handler must never be left orphaned (scanning with nothing that will " +
                    "ever stop it) after a start-destroy race",
                handler.bluetoothHandler,
            )
        }
    }
}
