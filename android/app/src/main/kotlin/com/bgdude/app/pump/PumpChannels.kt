package com.bgdude.app.pump

/**
 * Single source of truth for the platform-channel names shared with the Dart side
 * (TASK-111). These must match `lib/pump/channels.dart` exactly — a typo yields a dead
 * channel with no compile error.
 */
object PumpChannels {
    const val EVENT_CHANNEL = "bgdude/pump_events"
    const val COMMAND_CHANNEL = "bgdude/pump_commands"
}
