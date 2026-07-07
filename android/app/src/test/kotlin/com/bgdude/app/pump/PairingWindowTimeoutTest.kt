package com.bgdude.app.pump

import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import com.welie.blessed.BluetoothPeripheral
import java.time.Duration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * TASK-33 (AC#5): a scan or pairing-code wait that never reaches CONNECTED must give up
 * after a bounded window rather than running forever with no feedback -- see
 * PairingWindowPolicy for the durations and PumpCommHandler for the Handler/Looper wiring
 * this test drives via Robolectric's fake-time main looper.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PairingWindowTimeoutTest {

    private class RecordingListener : PumpCommHandler.Listener {
        val states = mutableListOf<NativeConnectionState>()
        override fun onState(state: NativeConnectionState) { states.add(state) }
        override fun onSnapshotUpdated(snapshot: MutableSnapshot) {}
        override fun onPairingCodeRequired(type: PairingCodeType) {}
        override fun onCriticalError(message: String) {}
    }

    @Test
    fun `a scan that never finds a pump times out to ERROR and stops the handler`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val listener = RecordingListener()
        val handler = PumpCommHandler(context, listener)

        handler.start(null)
        assertEquals(ConnectionStage.SCANNING, listener.states.last().stage)

        shadowOf(Looper.getMainLooper())
            .idleFor(Duration.ofMillis(PairingWindowPolicy.SCAN_TIMEOUT_MS + 1))

        assertEquals(ConnectionStage.ERROR, listener.states.last().stage)
        assertNull(
            "the timed-out scan must actually be stopped, not left running",
            handler.bluetoothHandler,
        )
    }

    @Test
    fun `a pairing code that is never submitted times out to ERROR`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val listener = RecordingListener()
        val handler = PumpCommHandler(context, listener)
        val peripheral = mock(BluetoothPeripheral::class.java)

        handler.onWaitingForPairingCode(peripheral, null)
        assertEquals(ConnectionStage.AWAITING_PAIRING_CODE, listener.states.last().stage)

        shadowOf(Looper.getMainLooper())
            .idleFor(Duration.ofMillis(PairingWindowPolicy.PAIRING_CODE_TIMEOUT_MS + 1))

        assertEquals(ConnectionStage.ERROR, listener.states.last().stage)
    }

    @Test
    fun `submitting a code before the window expires cancels the timeout`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val listener = RecordingListener()
        val handler = PumpCommHandler(context, listener)
        val peripheral = mock(BluetoothPeripheral::class.java)

        handler.onWaitingForPairingCode(peripheral, null)
        handler.submitPairingCode("123456", PairingCodeType.SHORT_6CHAR)
        val stateCountAfterSubmit = listener.states.size

        // Advance well past the entry-timeout window that would otherwise have fired.
        shadowOf(Looper.getMainLooper())
            .idleFor(Duration.ofMillis(PairingWindowPolicy.PAIRING_CODE_TIMEOUT_MS + 1))

        assertTrue(
            "cancelled timeout must not fire a spurious ERROR after the code was submitted",
            listener.states.size == stateCountAfterSubmit ||
                listener.states.last().stage != ConnectionStage.ERROR,
        )
    }
}
