package com.bgdude.app.pump

/**
 * TASK-33 (AC#5): a scan or pairing-code wait that never reaches CONNECTED previously ran
 * forever — a pump left out of range, or a user who opens the pairing dialog and never
 * finishes it, left the service silently scanning/waiting with no feedback and no way out
 * short of force-closing the app. These are the two timeouts that bound each stage; the
 * actual scheduling (Handler/Looper) lives in [PumpCommHandler], but the durations are a
 * single source of truth here so tests reference the same constants as production code
 * instead of duplicating magic numbers.
 */
object PairingWindowPolicy {

    /** No pump discovered within this long after `start()`: give up and surface an error. */
    const val SCAN_TIMEOUT_MS = 2 * 60_000L // 2 minutes

    /** No pairing code submitted within this long of being prompted: give up. */
    const val PAIRING_CODE_TIMEOUT_MS = 5 * 60_000L // 5 minutes

    /**
     * TASK-278: bounds the bonding/authentication phase from the moment a pairing code is
     * submitted (or an auto-repair with a saved code kicks off) through CONNECTED. A JPAKE
     * handshake normally finishes in a few seconds when the pump is in range; a minute is
     * generous headroom for a slow handshake while still giving up on a pump that has gone
     * silent (BLE drop / out of range mid-bonding) rather than hanging forever.
     */
    const val BONDING_TIMEOUT_MS = 60_000L // 1 minute
}
