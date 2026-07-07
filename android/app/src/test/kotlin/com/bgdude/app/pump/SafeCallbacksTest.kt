package com.bgdude.app.pump

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * TASK-189: a pumpx2/BLE callback that throws must not propagate (it would kill the
 * foreground service process), and a subsequent good callback must still process.
 */
class SafeCallbacksTest {

    private val logged = mutableListOf<Pair<String, Throwable>>()

    @Before
    fun captureLog() {
        SafeCallbacks.logSink = { msg, t -> logged.add(msg to t) }
    }

    @After
    fun resetLog() {
        SafeCallbacks.logSink = { _, _ -> }
    }

    @Test
    fun `a throwing callback does not propagate and is logged with its name`() {
        SafeCallbacks.run("onReceiveMessage(CGMStatusResponse)") {
            throw IllegalStateException("decode edge")
        }
        assertEquals(1, logged.size)
        assertTrue(logged[0].first.contains("onReceiveMessage(CGMStatusResponse)"))
        assertTrue(logged[0].second is IllegalStateException)
    }

    @Test
    fun `a subsequent good callback still processes after a throw`() {
        var processed = false
        SafeCallbacks.run("bad") { throw RuntimeException("boom") }
        SafeCallbacks.run("good") { processed = true }
        assertTrue(processed)
        assertEquals(1, logged.size)
    }

    @Test
    fun `the fallback variant returns the fallback on a throw`() {
        val reconnect = SafeCallbacks.run("onPumpDisconnected", fallback = true) {
            throw RuntimeException("boom")
            @Suppress("UNREACHABLE_CODE")
            false
        }
        assertTrue(reconnect)
        assertEquals(1, logged.size)
    }

    @Test
    fun `the fallback variant passes the value through when the body succeeds`() {
        val accepted = SafeCallbacks.run("onPumpDiscovered", fallback = true) { false }
        assertFalse(accepted)
        assertTrue(logged.isEmpty())
    }

    @Test
    fun `even a throwing log sink cannot make the guard throw`() {
        SafeCallbacks.logSink = { _, _ -> throw AssertionError("sink is broken too") }
        SafeCallbacks.run("onPumpCriticalError") { throw RuntimeException("original") }
        // Reaching here IS the assertion: nothing propagated.
    }
}
