package com.bgdude.app.pump

import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import com.welie.blessed.BluetoothPeripheral
import java.time.Duration
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * TASK-290: `@Volatile` (TASK-277) closed the visibility gap on the linear pairing path
 * but not atomicity -- `scheduleTimeout`'s cancel-then-set-then-postDelayed sequence and
 * `cancelTimeout`'s read-then-remove-then-null sequence could still interleave across
 * threads with no lock covering them, leaving two Runnables genuinely queued while
 * `pendingTimeout` referenced only the last writer. The orphaned one fires later and
 * tears down an already-live connection. `timeoutLock` makes each function's body a
 * single atomic unit; these tests pin that no interleaving can produce two live timeouts.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PairingTimeoutConcurrencyTest {

    private class RecordingListener : PumpCommHandler.Listener {
        val states = mutableListOf<NativeConnectionState>()
        override fun onState(state: NativeConnectionState) { states.add(state) }
        override fun onSnapshotUpdated(snapshot: MutableSnapshot) {}
        override fun onPairingCodeRequired(type: PairingCodeType) {}
        override fun onCriticalError(message: String) {}
    }

    /** Two threads racing the identical schedule call (e.g. a duplicate BLE discovery
     *  callback) must never leave two Runnables both queued -- whichever one wins,
     *  exactly one timeout may ever fire. Released simultaneously and repeated many
     *  times to make either interleaving likely to occur at least once. */
    @Test
    fun `two concurrent onWaitingForPairingCode calls never double-schedule the timeout`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()

        repeat(300) {
            val listener = RecordingListener()
            val handler = PumpCommHandler(context, listener)
            val peripheral = mock(BluetoothPeripheral::class.java)
            val release = CountDownLatch(1)
            val done = CountDownLatch(2)

            val t1 = Thread {
                release.await()
                handler.onWaitingForPairingCode(peripheral, null)
                done.countDown()
            }
            val t2 = Thread {
                release.await()
                handler.onWaitingForPairingCode(peripheral, null)
                done.countDown()
            }
            t1.start()
            t2.start()
            release.countDown()
            assertTrue("both calls did not complete", done.await(5, TimeUnit.SECONDS))

            shadowOf(Looper.getMainLooper())
                .idleFor(Duration.ofMillis(PairingWindowPolicy.PAIRING_CODE_TIMEOUT_MS + 1))

            val errorFires = listener.states.count { it.stage == ConnectionStage.ERROR }
            assertTrue(
                "expected at most one orphan-free timeout fire, got $errorFires -- a "
                    + "second means a Runnable survived uncancelled from the losing call",
                errorFires <= 1,
            )
        }
    }

    /** Races `start()` (schedules the scan timeout, inside `bluetoothLock`) against
     *  `onWaitingForPairingCode` (cancels it and schedules the pairing-code timeout,
     *  holding NO lock) -- the exact gap TASK-290 was filed for, since the two don't
     *  share `bluetoothLock`. Whichever schedule genuinely wins, the loser's Runnable
     *  must be actually removed, not merely disowned by the field. */
    @Test
    fun `start racing onWaitingForPairingCode never leaves the scan timeout orphaned`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()

        repeat(300) {
            val listener = RecordingListener()
            val handler = PumpCommHandler(context, listener)
            val peripheral = mock(BluetoothPeripheral::class.java)
            val release = CountDownLatch(1)
            val done = CountDownLatch(2)

            val startHandlerThread = HandlerThread("test-pairing").apply { start() }
            val startHandler = Handler(startHandlerThread.looper)
            startHandler.post {
                release.await()
                handler.start(null)
                done.countDown()
            }
            val callbackThread = Thread {
                release.await()
                handler.onWaitingForPairingCode(peripheral, null)
                done.countDown()
            }
            callbackThread.start()
            release.countDown()
            assertTrue("start/onWaitingForPairingCode did not complete", done.await(5, TimeUnit.SECONDS))
            startHandlerThread.quitSafely()

            // Past the (shorter) scan-timeout window only -- if a scan Runnable was
            // orphaned alongside a genuinely-scheduled pairing-code one, this is where
            // the orphan fires and spuriously tears the connection back down.
            shadowOf(Looper.getMainLooper())
                .idleFor(Duration.ofMillis(PairingWindowPolicy.SCAN_TIMEOUT_MS + 1))

            val errorFires = listener.states.count { it.stage == ConnectionStage.ERROR }
            assertTrue(
                "expected at most one timeout fire in the scan window, got $errorFires",
                errorFires <= 1,
            )
        }
    }
}
