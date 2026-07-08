package com.bgdude.app.garmin

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * TASK-201: GarminSender.health() is the Dart-side system-health screen's only
 * visibility into native watch delivery. Exercising send()'s actual success/failure
 * recording needs a live (or Mockito-doubled) ConnectIQ instance -- initialize()
 * hardcodes the real ConnectIQ.getInstance(...) call, which Robolectric can't
 * complete a real SDK handshake for, so this covers what IS reachable without
 * further dependency-injection work on GarminSender (a bigger change than this
 * ticket's ask): the health snapshot's shape and its "nothing sent yet" default.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class GarminSenderTest {

    private val app get() = ApplicationProvider.getApplicationContext<Application>()

    @Test
    fun `health() reports nothing sent yet before any send attempt`() {
        val sender = GarminSender(app)
        val health = sender.health()

        assertNull(health["lastSuccessAtMs"])
        assertEquals(0, health["consecutiveFailures"])
    }

    @Test
    fun `GarminIntegration health() falls back to a safe default with no sender`() {
        // GarminIntegration.init(context) is never called in this test, so its
        // private `sender` stays null -- health() must not throw or return null.
        val health = GarminIntegration.health()

        assertNull(health["lastSuccessAtMs"])
        assertEquals(0, health["consecutiveFailures"])
    }

    // TASK-264: a typical user installs only ONE of the three watch targets --
    // send() pushes to all three every cycle, so the other two structurally
    // fail every time ("app not installed"). Before this fix that shared one
    // consecutiveFailures counter, so the row flapped red purely on async
    // callback ordering even though delivery to the installed target was
    // working perfectly. These exercise the aggregation in health() directly
    // (recordSendSuccess/recordSendFailure are internal for exactly this --
    // send() itself can't be driven without a real Connect IQ SDK handshake).

    @Test
    fun `one succeeding target plus two not-installed targets reads healthy`() {
        val sender = GarminSender(app)

        sender.recordSendSuccess(GarminSender.WATCH_FACE_UUID)
        sender.recordSendFailure(GarminSender.WATCH_APP_UUID)
        sender.recordSendFailure(GarminSender.DATA_FIELD_UUID)
        val health = sender.health()

        assertEquals(0, health["consecutiveFailures"])
        assertEquals(
            "the row must report the installed target's success, not stay null "
                + "because two other targets never succeeded",
            true, health["lastSuccessAtMs"] != null,
        )
    }

    @Test
    fun `it stays healthy across repeated cycles of one success, two not-installed`() {
        val sender = GarminSender(app)

        repeat(5) {
            sender.recordSendSuccess(GarminSender.WATCH_FACE_UUID)
            sender.recordSendFailure(GarminSender.WATCH_APP_UUID)
            sender.recordSendFailure(GarminSender.DATA_FIELD_UUID)
        }

        assertEquals(0, sender.health()["consecutiveFailures"])
    }

    @Test
    fun `all three targets failing together is a real problem, not masked`() {
        val sender = GarminSender(app)

        sender.recordSendFailure(GarminSender.WATCH_APP_UUID)
        sender.recordSendFailure(GarminSender.WATCH_FACE_UUID)
        sender.recordSendFailure(GarminSender.DATA_FIELD_UUID)

        assertEquals(
            "when EVERY target fails, that's a genuine send-path problem and "
                + "must still surface as unhealthy",
            1, sender.health()["consecutiveFailures"],
        )
        assertNull(sender.health()["lastSuccessAtMs"])
    }

    @Test
    fun `recordSendFailureAllTargets advances every target's streak together`() {
        val sender = GarminSender(app)

        sender.recordSendFailureAllTargets()
        sender.recordSendFailureAllTargets()

        assertEquals(2, sender.health()["consecutiveFailures"])
    }

    @Test
    fun `a later failure on the previously-healthy target does not erase its prior success time`() {
        val sender = GarminSender(app)

        sender.recordSendSuccess(GarminSender.WATCH_FACE_UUID)
        val afterSuccess = sender.health()["lastSuccessAtMs"]
        sender.recordSendFailure(GarminSender.WATCH_FACE_UUID)
        val afterFailure = sender.health()["lastSuccessAtMs"]

        assertEquals(
            "a target's own failure only resets ITS OWN streak, not the "
                + "recorded time of its last real success",
            afterSuccess, afterFailure,
        )
    }
}
