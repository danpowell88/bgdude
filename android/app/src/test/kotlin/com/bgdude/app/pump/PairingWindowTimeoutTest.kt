package com.bgdude.app.pump

import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import com.jwoglom.pumpx2.pump.PumpState
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
    fun `submitting a code cancels the entry-timeout, not just defers it`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val listener = RecordingListener()
        val handler = PumpCommHandler(context, listener)
        val peripheral = mock(BluetoothPeripheral::class.java)

        handler.onWaitingForPairingCode(peripheral, null)
        handler.submitPairingCode("123456", PairingCodeType.SHORT_6CHAR)

        // Advance past where the OLD entry-timeout window would have fired, but still
        // inside the new bonding-timeout window (TASK-278) -- must stay quiet here;
        // this specific window only exercises the entry-timeout's cancellation, not
        // the new bonding timeout (covered separately below).
        shadowOf(Looper.getMainLooper())
            .idleFor(Duration.ofMillis(PairingWindowPolicy.BONDING_TIMEOUT_MS - 1))

        assertTrue(
            "the entry-timeout must not fire a spurious ERROR after the code was submitted",
            listener.states.last().stage != ConnectionStage.ERROR,
        )
    }

    @Test
    fun `a pump that goes silent after the pairing code is submitted times out to ERROR (TASK-278)`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val listener = RecordingListener()
        val handler = PumpCommHandler(context, listener)
        val peripheral = mock(BluetoothPeripheral::class.java)

        handler.onWaitingForPairingCode(peripheral, null)
        handler.submitPairingCode("123456", PairingCodeType.SHORT_6CHAR)
        // Nothing reaches a terminal callback (onPumpConnected / onInvalidPairingCode /
        // onPumpCriticalError) -- the pump went silent mid-bonding, e.g. dropped out of
        // BLE range during the JPAKE handshake.

        shadowOf(Looper.getMainLooper())
            .idleFor(Duration.ofMillis(PairingWindowPolicy.BONDING_TIMEOUT_MS + 1))

        assertEquals(
            "a silent pump during bonding must time out rather than hang forever",
            ConnectionStage.ERROR,
            listener.states.last().stage,
        )
        assertNull(
            "the timed-out bonding attempt must actually be stopped, not left running",
            handler.bluetoothHandler,
        )
    }

    @Test
    fun `reaching CONNECTED before the bonding timeout cancels it`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val listener = RecordingListener()
        val handler = PumpCommHandler(context, listener)
        val peripheral = mock(BluetoothPeripheral::class.java)

        handler.onWaitingForPairingCode(peripheral, null)
        handler.submitPairingCode("123456", PairingCodeType.SHORT_6CHAR)
        handler.onPumpConnected(peripheral)
        val stateCountAfterConnect = listener.states.size

        // Advance well past the bonding-timeout window that would otherwise have fired.
        shadowOf(Looper.getMainLooper())
            .idleFor(Duration.ofMillis(PairingWindowPolicy.BONDING_TIMEOUT_MS + 1))

        assertEquals(
            "a cancelled bonding timeout must not fire a spurious state change after CONNECTED",
            stateCountAfterConnect,
            listener.states.size,
        )
    }

    @Test
    fun `an invalid pairing code cancels the bonding timeout`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val listener = RecordingListener()
        val handler = PumpCommHandler(context, listener)
        val peripheral = mock(BluetoothPeripheral::class.java)

        handler.onWaitingForPairingCode(peripheral, null)
        handler.submitPairingCode("123456", PairingCodeType.SHORT_6CHAR)
        handler.onInvalidPairingCode(peripheral, null)
        assertEquals(ConnectionStage.ERROR, listener.states.last().stage)
        val stateCountAfterInvalid = listener.states.size

        shadowOf(Looper.getMainLooper())
            .idleFor(Duration.ofMillis(PairingWindowPolicy.BONDING_TIMEOUT_MS + 1))

        assertEquals(
            "a cancelled bonding timeout must not fire a second, spurious ERROR",
            stateCountAfterInvalid,
            listener.states.size,
        )
    }

    @Test
    fun `an auto-repair with a saved code is also bounded by the bonding timeout`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val listener = RecordingListener()
        val handler = PumpCommHandler(context, listener)
        val peripheral = mock(BluetoothPeripheral::class.java)
        PumpState.setPairingCode(context, "123456")

        // No user interaction -- onWaitingForPairingCode auto-pairs with the saved code
        // (re-pair after a restart), the same path a fresh manual submit takes.
        handler.onWaitingForPairingCode(peripheral, null)

        shadowOf(Looper.getMainLooper())
            .idleFor(Duration.ofMillis(PairingWindowPolicy.BONDING_TIMEOUT_MS + 1))

        assertEquals(
            "a silent pump during an auto-repair's bonding must also time out",
            ConnectionStage.ERROR,
            listener.states.last().stage,
        )
    }
}
