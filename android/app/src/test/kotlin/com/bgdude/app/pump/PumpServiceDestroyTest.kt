package com.bgdude.app.pump

import com.bgdude.app.garmin.GarminIntegration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * TASK-202: nothing previously stopped the BLE comm handler or shut down the Garmin
 * SDK when the service itself was torn down (only reachable via the command
 * channel) -- repeated restart cycles would accumulate BLE scan state and Connect
 * IQ connections indefinitely.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PumpServiceDestroyTest {

    @Test
    fun `onDestroy invokes commHandler stop (observed via its IDLE state emission)`() {
        val controller = Robolectric.buildService(PumpService::class.java).create()
        val service = controller.get()

        val states = mutableListOf<NativeConnectionState>()
        service.callbacks = object : PumpService.Callbacks {
            override fun onState(state: NativeConnectionState) {
                states.add(state)
            }
            override fun onSnapshot(json: String) {}
            override fun onPairingCodeRequired(type: PairingCodeType) {}
            override fun onCriticalError(message: String) {}
            override fun onTherapyProfile(json: String) {}
            override fun onProbeMessage(event: Map<String, Any?>) {}
        }

        controller.destroy()

        // PumpCommHandler.stop() unconditionally emits an IDLE state -- the only way
        // that fires here (onCreate never calls stop) is via onDestroy's new
        // commHandler?.stop() call.
        assertTrue(states.any { it.stage == ConnectionStage.IDLE })
    }

    @Test
    fun `onDestroy clears the commHandler reference so post-destroy calls are safe no-ops`() {
        val controller = Robolectric.buildService(PumpService::class.java).create()
        val service = controller.get()

        controller.destroy()

        // Calling a command method after destroy must not throw (commHandler is now
        // null; every wrapper is null-safe via ?.).
        service.stopScan()
        assertEquals("{}", service.snapshotJson())
    }

    /**
     * TASK-262: `TandemBluetoothHandler` is a process-wide singleton, so `start()` followed by
     * two `stop()`s (e.g. a UI-triggered `stopScan()` and then the service's own `onDestroy`)
     * used to double-close blessed's `BluetoothCentralManager` — the second `close()`
     * unregisters an already-unregistered broadcast receiver and throws
     * `IllegalArgumentException`. Both calls here must be no-ops the second time, not crash.
     */
    @Test
    fun `stopScan called twice after a real start does not throw`() {
        val controller = Robolectric.buildService(PumpService::class.java).create()
        val service = controller.get()

        service.startScan(null)
        service.stopScan()
        service.stopScan() // must not throw IllegalArgumentException: Receiver not registered
    }

    @Test
    fun `unpair followed by service onDestroy does not throw`() {
        val controller = Robolectric.buildService(PumpService::class.java).create()
        val service = controller.get()

        service.startScan(null)
        service.unpair()
        controller.destroy() // onDestroy's own stop() must not double-close the BLE central
    }

    @Test
    fun `onDestroy still reaches Garmin shutdown and super onDestroy after a double stop`() {
        val controller = Robolectric.buildService(PumpService::class.java).create()
        val service = controller.get()

        service.startScan(null)
        service.stopScan() // first close
        // onDestroy's commHandler.stop() would be a second close on the unfixed code path;
        // the service must still finish tearing down (no crash propagates out of onDestroy).
        controller.destroy()
    }

    /**
     * TASK-263: the tests above only ever observed teardown INDIRECTLY (an IDLE state
     * emission, or the absence of a crash) -- neither actually confirms the BLE central
     * was closed or that GarminIntegration.shutdown() ran, so a regression dropping
     * either call (half of TASK-202) would stay green.
     */
    @Test
    fun `onDestroy closes the BLE central and shuts down the Garmin SDK`() {
        val controller = Robolectric.buildService(PumpService::class.java).create()
        val service = controller.get()

        service.startScan(null)
        // Capture the handler before destroy nulls PumpService's own reference to it --
        // PumpCommHandler.destroy() nulls its OWN bluetoothHandler field as part of
        // tearing down, which is what actually proves the BLE central was closed.
        val handler = service.commHandler
        assertTrue(
            "precondition: starting a scan should have set up a real BLE handler",
            handler?.bluetoothHandler != null,
        )
        assertTrue(
            "precondition: onCreate's GarminIntegration.init should hold a sender",
            GarminIntegration.hasSender,
        )

        controller.destroy()

        assertNull(
            "onDestroy must close the BLE central (bluetoothHandler nulled by the "
                + "captured handler's own destroy/stopBluetooth), not just drop the "
                + "outer reference",
            handler?.bluetoothHandler,
        )
        assertFalse(
            "onDestroy must call GarminIntegration.shutdown() so watch delivery "
                + "actually stops, not just leave the sender running unobserved",
            GarminIntegration.hasSender,
        )
    }
}
