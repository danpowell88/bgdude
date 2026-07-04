package com.bgdude.app.pump

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger

/**
 * Implements the Pigeon-generated `PumpHostApi` (read-only command surface) by
 * forwarding to the bound [PumpService]. The generated interface `PumpHostApi` and its
 * data classes (`PumpStatusSnapshot`, `PumpConnectionState`, `HistoryLogEntry`, the
 * `PumpModel`/`PairingCodeType`/`ConnectionStage` enums) live in `PumpApi.g.kt`.
 *
 * Once Pigeon has generated that file, change the class declaration to:
 *   `class PumpHostApiImpl(...) : PumpHostApi { ... }`
 * and map the native types below onto the generated ones. The method bodies here are the
 * real logic; only the generated type names need wiring.
 */
class PumpHostApiImpl(private val context: Context) {

    private var service: PumpService? = null

    fun bind(service: PumpService?) {
        this.service = service
    }

    fun startService(callback: (Result<Unit>) -> Unit) {
        // Service is already started/bound by PumpBridge.attach(); this is idempotent.
        callback(Result.success(Unit))
    }

    fun stopService(callback: (Result<Unit>) -> Unit) {
        service?.stopScan()
        callback(Result.success(Unit))
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

    /** Returns the latest snapshot JSON; the Dart side parses it (same schema as the
     * event channel) to avoid duplicating the Pigeon data class mapping here. */
    fun requestStatusJson(callback: (Result<String>) -> Unit) {
        service?.requestStatus()
        callback(Result.success(service?.snapshotJson() ?: "{}"))
    }

    fun unpair(callback: (Result<Unit>) -> Unit) {
        service?.unpair()
        callback(Result.success(Unit))
    }
}

/**
 * Thin shim that calls the generated `PumpHostApi.setUp(messenger, impl)`. Kept separate
 * so a missing generated file produces one obvious compile error here rather than in the
 * bridge. Replace the body with the generated call after running Pigeon.
 */
object PumpHostApiRegistrar {
    fun register(messenger: BinaryMessenger, impl: PumpHostApiImpl) {
        // PumpHostApi.setUp(messenger, GeneratedAdapter(impl))
        // Until Pigeon is run, this is a no-op placeholder — the EventChannel still works
        // for read streaming, so the app can be exercised before the command surface is
        // fully generated.
    }
}
