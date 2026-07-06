package com.bgdude.app.pump

import com.jwoglom.pumpx2.pump.messages.bluetooth.Characteristic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM unit tests for [ProtocolProbe] — the read-only guarantee of the Protocol Explorer.
 *
 * These build real pumpx2 request objects (pumpx2-messages is on the test classpath) and
 * assert that only unsigned CURRENT_STATUS reads are ever produced, and that anything
 * control/insulin-affecting is refused **by construction** (it can never become a Message
 * that could be sent).
 */
class ProtocolProbeTest {

    @Test
    fun `accepts a plain currentStatus read`() {
        val r = ProtocolProbe.buildSafeRequest("HomeScreenMirrorRequest")
        assertTrue("HomeScreenMirror should be allowed", r is ProtocolProbe.Result.Ok)
        val msg = (r as ProtocolProbe.Result.Ok).message
        assertEquals(Characteristic.CURRENT_STATUS, msg.props().characteristic)
    }

    @Test
    fun `accepts the documented-opportunity reads`() {
        for (name in listOf(
            "PumpFeaturesV2Request",
            "PumpSettingsRequest",
            "PumpGlobalsRequest",
            "ControlIQSleepScheduleRequest",
            "MalfunctionStatusRequest",
            "CGMHardwareInfoRequest",
            "SecretMenuRequest",
        )) {
            assertTrue("$name should be allowed",
                ProtocolProbe.buildSafeRequest(name) is ProtocolProbe.Result.Ok)
        }
    }

    @Test
    fun `refuses a control request even if named directly`() {
        // A control (insulin-affecting) request lives in request.control, so the package
        // gate refuses it — it never becomes a Message.
        val r = ProtocolProbe.buildSafeRequest("BolusPermissionRequest")
        assertTrue("control request must be refused", r is ProtocolProbe.Result.Refused)
    }

    @Test
    fun `refuses an unknown class`() {
        val r = ProtocolProbe.buildSafeRequest("TotallyMadeUpRequest")
        assertTrue(r is ProtocolProbe.Result.Refused)
        assertTrue((r as ProtocolProbe.Result.Refused).reason.contains("unknown"))
    }

    @Test
    fun `refuses fully-qualified control class name`() {
        // Even if someone passes a dotted name, only the simple name is used and it is
        // resolved within request.currentStatus — a control fqcn cannot escape the gate.
        val r = ProtocolProbe.buildSafeRequest(
            "com.jwoglom.pumpx2.pump.messages.request.control.BolusPermissionRequest")
        assertTrue(r is ProtocolProbe.Result.Refused)
    }

    @Test
    fun `describe produces a serialisable map with hex cargo`() {
        val msg = (ProtocolProbe.buildSafeRequest("HomeScreenMirrorRequest")
                as ProtocolProbe.Result.Ok).message
        val map = ProtocolProbe.describe(msg, "tx", 1_700_000_000_000L)
        assertEquals("probe", map["kind"])
        assertEquals("tx", map["direction"])
        assertEquals("HomeScreenMirrorRequest", map["name"])
        assertEquals("CURRENT_STATUS", map["characteristic"])
        assertNotNull("opcode present", map["opcode"])
    }
}
