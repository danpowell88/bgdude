package com.bgdude.app.pump

import com.bgdude.app.widget.WidgetKeys
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Cross-language contract test (TASK-111): pins the channel names and widget prefs keys to
 * the same literals the Dart side hard-asserts (lib/pump/channels.dart, widget_keys.dart).
 */
class ChannelContractTest {

    @Test
    fun channel_names_match_the_dart_contract() {
        assertEquals("bgdude/pump_events", PumpChannels.EVENT_CHANNEL)
        assertEquals("bgdude/pump_commands", PumpChannels.COMMAND_CHANNEL)
    }

    @Test
    fun widget_key_set_matches_the_dart_contract() {
        assertEquals(
            setOf("bg_text", "bg_trend", "bg_unit", "iob_text", "bg_range", "cgm_epoch_ms"),
            WidgetKeys.ALL,
        )
    }
}
