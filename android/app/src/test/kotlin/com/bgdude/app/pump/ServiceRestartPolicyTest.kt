package com.bgdude.app.pump

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * TASK-178: a sticky restart (null intent) with a saved pump must resume the scan;
 * a fresh install must not scan on its own; no permission never scans.
 */
class ServiceRestartPolicyTest {

    @Test
    fun `sticky restart with a saved MAC resumes the connection`() {
        assertTrue(ServiceRestartPolicy.shouldResume(
            nullIntent = true,
            autoReconnectExtra = false,
            hasBluetoothPermission = true,
            hasSavedMac = true,
        ))
    }

    @Test
    fun `sticky restart with NO saved pump does not scan (fresh install)`() {
        assertFalse(ServiceRestartPolicy.shouldResume(
            nullIntent = true,
            autoReconnectExtra = false,
            hasBluetoothPermission = true,
            hasSavedMac = false,
        ))
    }

    @Test
    fun `the boot receiver's explicit flag keeps resuming (TASK-12 behaviour)`() {
        assertTrue(ServiceRestartPolicy.shouldResume(
            nullIntent = false,
            autoReconnectExtra = true,
            hasBluetoothPermission = true,
            hasSavedMac = false,
        ))
    }

    @Test
    fun `a normal explicit start without the flag does not auto-scan`() {
        // The Dart side drives scanning in this case (PumpBridge.startScan).
        assertFalse(ServiceRestartPolicy.shouldResume(
            nullIntent = false,
            autoReconnectExtra = false,
            hasBluetoothPermission = true,
            hasSavedMac = true,
        ))
    }

    @Test
    fun `no Bluetooth permission never resumes`() {
        assertFalse(ServiceRestartPolicy.shouldResume(
            nullIntent = true,
            autoReconnectExtra = true,
            hasBluetoothPermission = false,
            hasSavedMac = true,
        ))
    }
}
