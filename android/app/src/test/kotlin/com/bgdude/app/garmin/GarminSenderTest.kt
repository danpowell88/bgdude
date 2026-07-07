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
}
