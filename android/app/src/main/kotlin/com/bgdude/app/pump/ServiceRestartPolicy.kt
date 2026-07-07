package com.bgdude.app.pump

/**
 * TASK-178: when the STICKY pump service is restarted by the system after a kill,
 * Android delivers a NULL intent — the old code only re-foregrounded, so overnight
 * kills silently ended monitoring until the user opened the app. This pure policy
 * decides when the service must resume the pump connection itself; extracted so the
 * decision is JVM-testable without Robolectric.
 */
object ServiceRestartPolicy {

    /**
     * Whether to call `commHandler.start(savedMac)` from onStartCommand.
     *
     *  * [nullIntent] — a system sticky restart (process was killed).
     *  * [autoReconnectExtra] — the boot receiver's explicit flag (TASK-12).
     *  * [hasBluetoothPermission] — scanning without it would throw.
     *  * [hasSavedMac] — a pump was paired before; without one there is nothing
     *    to resume (a fresh install must not scan on its own).
     */
    fun shouldResume(
        nullIntent: Boolean,
        autoReconnectExtra: Boolean,
        hasBluetoothPermission: Boolean,
        hasSavedMac: Boolean,
    ): Boolean {
        if (!hasBluetoothPermission) return false
        if (autoReconnectExtra) return true // boot receiver path (existing behaviour)
        // Sticky restart: resume only when a pump was actually paired.
        return nullIntent && hasSavedMac
    }
}
