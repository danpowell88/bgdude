package com.bgdude.app.pump

import com.jwoglom.pumpx2.pump.messages.models.PairingCodeType as X2PairingCodeType
import com.jwoglom.pumpx2.pump.messages.response.authentication.AbstractCentralChallengeResponse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * TASK-165: regression pins for the commit-d18d72e JPAKE pairing fixes. A refactor
 * that re-defaults the scheme to the 16-char challenge, or gates `pair()` on a
 * non-null challenge, silently breaks pairing for every 6-digit (JPAKE) pump.
 */
class PairingDecisionTest {

    private class FakeChallenge : AbstractCentralChallengeResponse() {
        override fun parse(bytes: ByteArray) {}
        override fun getAppInstanceId(): Int = 0
    }

    @Test
    fun `JPAKE 6-digit code has NO central challenge and pair is still invoked`() {
        val request = PairingDecision.pairRequest(null, "123456")
        assertNull(request.challenge)
        assertTrue("pair() must run even with a null challenge (JPAKE handshake)",
            request.invokePair)
        assertEquals("123456", request.code)
    }

    @Test
    fun `the legacy 16-char scheme carries its central challenge through`() {
        val challenge = FakeChallenge()
        val request =
            PairingDecision.pairRequest(challenge, "0123456789ABCDEF")
        assertSame(challenge, request.challenge)
        assertTrue(request.invokePair)
    }

    @Test
    fun `a fresh pair defaults the scheme to SHORT_6CHAR (JPAKE)`() {
        assertEquals(X2PairingCodeType.SHORT_6CHAR, PairingDecision.initialScheme(null))
        assertEquals(X2PairingCodeType.SHORT_6CHAR, PairingDecision.initialScheme(""))
    }

    @Test
    fun `re-auth with a derived JPAKE secret keeps the existing scheme`() {
        assertNull(PairingDecision.initialScheme("cached-derived-secret"))
    }

    @Test
    fun `the pairing prompt matches the active scheme`() {
        assertEquals(PairingCodeType.LONG_16CHAR,
            PairingDecision.promptType(X2PairingCodeType.LONG_16CHAR))
        assertEquals(PairingCodeType.SHORT_6CHAR,
            PairingDecision.promptType(X2PairingCodeType.SHORT_6CHAR))
        // Unknown/unset falls back to the JPAKE prompt, matching the fresh-pair default.
        assertEquals(PairingCodeType.SHORT_6CHAR, PairingDecision.promptType(null))
    }
}
