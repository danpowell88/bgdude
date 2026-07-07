package com.bgdude.app.garmin

import android.content.Context
import android.util.Log
import com.garmin.android.connectiq.ConnectIQ
import com.garmin.android.connectiq.IQApp
import com.garmin.android.connectiq.IQDevice
import com.garmin.android.connectiq.exception.InvalidStateException
import com.garmin.android.connectiq.exception.ServiceUnavailableException

/**
 * Pushes pump snapshots to the bgdude Connect IQ watch app via the free Connect IQ
 * Mobile SDK (no paid Garmin Health API). The watch app UUID must match
 * `garmin/manifest.xml`.
 *
 * Failure-tolerant by design: if the Garmin Connect app isn't installed, no device is
 * paired, or the watch app isn't installed, every path logs and returns — the pump
 * service must never be destabilised by watch delivery.
 */
class GarminSender(private val context: Context) {

    /**
     * The bgdude Connect IQ products the phone pushes to — the widget, watch face and data
     * field each have their own app UUID (Connect IQ addresses messages per app), so a
     * reading is delivered to whichever the user has installed/open. UUIDs must match the
     * `id` in the matching garmin/manifest*.xml.
     */
    private val watchTargets = listOf(
        IQApp(WATCH_APP_UUID),
        IQApp(WATCH_FACE_UUID),
        IQApp(DATA_FIELD_UUID),
    )

    private var connectIQ: ConnectIQ? = null
    private var initialized = false
    private var lastSentAtMs = 0L

    /**
     * TASK-201: in-memory-only (not persisted across process restarts, unlike the
     * Dart-side SystemHealthNotifier subsystems) last-success time and consecutive
     * failure count, exposed to Dart via PumpBridge's "garminHealth" method call so
     * the system-health screen can show whether watch delivery is actually working
     * instead of only ever logging failures.
     */
    @Volatile private var lastSuccessAtMs: Long? = null
    @Volatile private var consecutiveFailures: Int = 0

    private fun recordSendSuccess() {
        lastSuccessAtMs = System.currentTimeMillis()
        consecutiveFailures = 0
    }

    private fun recordSendFailure() {
        consecutiveFailures += 1
    }

    /** Current health snapshot for the Dart-side system-health surface. */
    fun health(): Map<String, Any?> = mapOf(
        "lastSuccessAtMs" to lastSuccessAtMs,
        "consecutiveFailures" to consecutiveFailures,
    )

    fun initialize() {
        if (initialized) return
        try {
            val ciq = ConnectIQ.getInstance(context, ConnectIQ.IQConnectType.WIRELESS)
            ciq.initialize(context, false, object : ConnectIQ.ConnectIQListener {
                override fun onSdkReady() {
                    initialized = true
                    Log.i(TAG, "Connect IQ SDK ready")
                }

                override fun onInitializeError(status: ConnectIQ.IQSdkErrorStatus?) {
                    Log.i(TAG, "Connect IQ unavailable: $status (Garmin Connect app missing?)")
                    initialized = false
                }

                override fun onSdkShutDown() {
                    initialized = false
                }
            })
            connectIQ = ciq
        } catch (t: Throwable) {
            Log.i(TAG, "Connect IQ init failed; watch push disabled", t)
        }
    }

    /**
     * Send the snapshot payload to every connected Garmin device. Debounced to at most
     * one send per [MIN_SEND_INTERVAL_MS] — CGM updates every ~5 min, so anything more
     * frequent is UI-refresh noise the watch doesn't need.
     */
    fun send(payload: Map<String, Any?>) {
        val ciq = connectIQ ?: return
        if (!initialized) return
        val now = System.currentTimeMillis()
        if (now - lastSentAtMs < MIN_SEND_INTERVAL_MS) return

        try {
            val devices: List<IQDevice> = ciq.connectedDevices ?: emptyList()
            // No paired device is a normal state (the user may not own a Garmin
            // watch) — not a failure, so health is left untouched.
            if (devices.isEmpty()) return
            for (device in devices) {
                for (app in watchTargets) {
                    ciq.sendMessage(device, app, payload) { _, _, status ->
                        if (status == ConnectIQ.IQMessageStatus.SUCCESS) {
                            recordSendSuccess()
                        } else {
                            recordSendFailure()
                        }
                        Log.d(TAG, "watch send ${app.applicationId} → $status")
                    }
                }
            }
            lastSentAtMs = now
        } catch (e: InvalidStateException) {
            recordSendFailure()
            Log.i(TAG, "Connect IQ not in a sendable state", e)
        } catch (e: ServiceUnavailableException) {
            recordSendFailure()
            Log.i(TAG, "Garmin Connect service unavailable", e)
        } catch (t: Throwable) {
            recordSendFailure()
            Log.w(TAG, "watch send failed", t)
        }
    }

    fun shutdown() {
        try {
            connectIQ?.shutdown(context)
        } catch (_: Throwable) {
        }
        initialized = false
    }

    companion object {
        private const val TAG = "GarminSender"
        private const val MIN_SEND_INTERVAL_MS = 60_000L

        /** Keep in sync with the `id` in garmin/manifest.xml (widget). */
        const val WATCH_APP_UUID = "33a5cbffcdb94cdfa61c69ec806dec41"

        /** Keep in sync with garmin/manifest-watchface.xml (watch face). */
        const val WATCH_FACE_UUID = "5b464f4e38a24b0591aaac277b12f3d3"

        /** Keep in sync with garmin/manifest-datafield.xml (data field). */
        const val DATA_FIELD_UUID = "9306b7b1a5d148888b64c900377a5951"
    }
}
