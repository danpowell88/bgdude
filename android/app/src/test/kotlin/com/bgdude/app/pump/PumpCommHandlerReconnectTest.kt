package com.bgdude.app.pump

import androidx.test.core.app.ApplicationProvider
import com.welie.blessed.BluetoothPeripheral
import com.welie.blessed.HciStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * TASK-186: an unexpected pump disconnect must surface DISCONNECTED and ask pumpx2's BLE
 * handler to keep retrying — this is what makes an overnight signal drop self-heal instead
 * of silently ending monitoring.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PumpCommHandlerReconnectTest {

    private class RecordingListener : PumpCommHandler.Listener {
        val states = mutableListOf<NativeConnectionState>()
        override fun onState(state: NativeConnectionState) { states.add(state) }
        override fun onSnapshotUpdated(snapshot: MutableSnapshot) {}
        override fun onPairingCodeRequired(type: PairingCodeType) {}
        override fun onCriticalError(message: String) {}
    }

    @Test
    fun `disconnect emits DISCONNECTED and requests an automatic reconnect`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val listener = RecordingListener()
        val handler = PumpCommHandler(context, listener)
        val peripheral = mock(BluetoothPeripheral::class.java)

        val shouldReconnect = handler.onPumpDisconnected(peripheral, HciStatus.SUCCESS)

        assertTrue("must request an automatic reconnect", shouldReconnect)
        assertEquals(ConnectionStage.DISCONNECTED, listener.states.last().stage)
    }

    @Test
    fun `still requests a reconnect even for an unusual HCI status`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val listener = RecordingListener()
        val handler = PumpCommHandler(context, listener)
        val peripheral = mock(BluetoothPeripheral::class.java)

        val shouldReconnect =
            handler.onPumpDisconnected(peripheral, HciStatus.CONNECTION_TIMEOUT)

        assertTrue(shouldReconnect)
        assertEquals(ConnectionStage.DISCONNECTED, listener.states.last().stage)
    }
}
