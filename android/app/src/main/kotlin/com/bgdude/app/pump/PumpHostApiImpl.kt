package com.bgdude.app.pump

import android.content.Context
import android.os.Handler
import android.os.Looper
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Implements the read-only command surface for the `bgdude/pump_commands`
 * MethodChannel (dispatched in [PumpBridge]) by forwarding to the bound [PumpService].
 * All methods are safe no-ops while the service is not yet bound.
 */
class PumpHostApiImpl(
    @Suppress("unused") private val context: Context,
    private val pairingExecutor: ExecutorService = Executors.newSingleThreadExecutor(),
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
) {

    private var service: PumpService? = null

    fun bind(service: PumpService?) {
        this.service = service
    }

    /**
     * TASK-205: [PumpCommHandler.start] (via [PumpService.startScan]) and
     * [PumpCommHandler.submitPairingCode] both hit pumpx2's SharedPreferences-backed
     * `PumpState` synchronously — Flutter dispatches platform-channel method calls
     * on the main thread, so that disk I/O ran there as a minor ANR risk. Runs
     * [work] on a background executor and marshals the callback back onto the main
     * thread, since a Pigeon `Result` callback must be invoked there.
     */
    private fun runOffMain(work: () -> Unit, callback: (Result<Unit>) -> Unit) {
        pairingExecutor.execute {
            val result = try {
                work()
                Result.success(Unit)
            } catch (t: Throwable) {
                Result.failure<Unit>(t)
            }
            mainHandler.post { callback(result) }
        }
    }

    fun startScan(macFilter: String?, callback: (Result<Unit>) -> Unit) {
        runOffMain({ service?.startScan(macFilter) }, callback)
    }

    fun stopScan(callback: (Result<Unit>) -> Unit) {
        service?.stopScan()
        callback(Result.success(Unit))
    }

    fun submitPairingCode(code: String, type: PairingCodeType, callback: (Result<Unit>) -> Unit) {
        runOffMain({ service?.submitPairingCode(code, type) }, callback)
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
