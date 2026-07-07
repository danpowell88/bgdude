package com.bgdude.app.pump

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import java.util.concurrent.AbstractExecutorService
import java.util.concurrent.ExecutorService
import java.util.concurrent.TimeUnit

/**
 * TASK-267: pumpx2's `TandemBluetoothHandler` constructs its own internal
 * `android.os.Handler` the first time [PumpCommHandler.start] calls `getInstance()` — the
 * no-arg `Handler()` constructor requires `Looper.prepare()` to have already run on the
 * calling thread. A plain `Executors.newSingleThreadExecutor()` thread has no Looper, so
 * the FIRST `startScan`/`submitPairingCode`/`unpair` dispatched through [PumpHostApiImpl]'s
 * pairing executor crashed with "Can't create handler inside thread that has not called
 * Looper.prepare()" — real Android framework behaviour (verified with a Robolectric repro),
 * not a test-only quirk, so this broke pump pairing/scanning on a real device too. A
 * [HandlerThread] prepares and runs a Looper for us.
 */
private class LooperExecutorService(name: String) : AbstractExecutorService() {
    private val thread = HandlerThread(name).apply { start() }
    private val handler = Handler(thread.looper)

    override fun execute(command: Runnable) {
        handler.post(command)
    }

    override fun shutdown() {
        thread.quitSafely()
    }
    override fun shutdownNow(): MutableList<Runnable> {
        thread.quit()
        return mutableListOf()
    }
    override fun isShutdown(): Boolean = !thread.isAlive
    override fun isTerminated(): Boolean = !thread.isAlive
    override fun awaitTermination(timeout: Long, unit: TimeUnit): Boolean {
        thread.join(unit.toMillis(timeout))
        return !thread.isAlive
    }
}

/**
 * Implements the read-only command surface for the `bgdude/pump_commands`
 * MethodChannel (dispatched in [PumpBridge]) by forwarding to the bound [PumpService].
 * All methods are safe no-ops while the service is not yet bound.
 */
class PumpHostApiImpl(
    @Suppress("unused") private val context: Context,
    private val pairingExecutor: ExecutorService = LooperExecutorService("bgdude-pairing"),
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
        // TASK-267: PumpState.resetState()/PairedPump.clear() hit SharedPreferences
        // synchronously (pumpx2's PumpState uses the blocking Editor.commit(), verified via
        // javap) -- same ANR risk TASK-205 fixed for startScan/submitPairingCode.
        runOffMain({ service?.unpair() }, callback)
    }

    /** TASK-267: [pairingExecutor] is a non-daemon single thread created per engine
     *  attach — call from [PumpBridge.detach] or it leaks one worker thread per
     *  attach/detach cycle (e.g. every hot restart during development). */
    fun shutdown() {
        pairingExecutor.shutdown()
    }
}
