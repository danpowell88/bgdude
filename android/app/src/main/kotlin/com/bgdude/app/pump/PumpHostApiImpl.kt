package com.bgdude.app.pump

import android.content.Context

/**
 * Implements the read-only command surface for the `bgdude/pump_commands`
 * MethodChannel (dispatched in [PumpBridge]) by forwarding to the bound [PumpService].
 * All methods are safe no-ops while the service is not yet bound.
 */
class PumpHostApiImpl(@Suppress("unused") private val context: Context) {

    private var service: PumpService? = null

    fun bind(service: PumpService?) {
        this.service = service
    }

    fun startScan(macFilter: String?, callback: (Result<Unit>) -> Unit) {
        service?.startScan(macFilter)
        callback(Result.success(Unit))
    }

    fun stopScan(callback: (Result<Unit>) -> Unit) {
        service?.stopScan()
        callback(Result.success(Unit))
    }

    fun submitPairingCode(code: String, type: PairingCodeType, callback: (Result<Unit>) -> Unit) {
        service?.submitPairingCode(code, type)
        callback(Result.success(Unit))
    }

    /** Triggers a fresh status poll and returns the latest snapshot JSON (same schema
     * as the event channel, so the Dart side has a single parser). */
    fun requestStatusJson(callback: (Result<String>) -> Unit) {
        service?.requestStatus()
        callback(Result.success(service?.snapshotJson() ?: "{}"))
    }

    fun unpair(callback: (Result<Unit>) -> Unit) {
        service?.unpair()
        callback(Result.success(Unit))
    }
}
