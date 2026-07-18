package com.bgdude.app.garmin

import android.app.Application
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
// Takes an [Application], not a bare [Context], deliberately: GarminIntegration holds
// this instance in a static (object) field for the process lifetime, and an Application
// is the one Context that legitimately lives that long. Typing it here encodes the
// invariant instead of relying on every call site remembering `.applicationContext`
// — and is what clears Android Lint's StaticFieldLeak without a suppression (issue #334).
class GarminSender(private val context: Application) {

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
     *
     * TASK-264: tracked PER TARGET (keyed by [IQApp.getApplicationId]), not as one
     * shared counter. [send] pushes to all three watchTargets (widget/watch face/data
     * field) every cycle, but a typical user has only ONE installed -- with a single
     * shared counter, that produces one success plus two app-not-installed failures
     * per cycle, and the final value depended purely on async callback ordering
     * (Connect IQ's IQMessageStatus has no distinct "not installed" value to filter
     * on instead -- confirmed via the SDK jar, see backlog comment). [health] then
     * aggregates across targets so one consistently-working target reads as healthy
     * regardless of how many of the others aren't installed. [targetLock] guards the
     * map since callbacks for different targets can land on different threads.
     *
     * `internal` (not `private`): [send] can't be driven in a Robolectric unit test
     * without a real Connect IQ SDK handshake (see GarminSenderTest's file doc), so
     * these are exposed for tests to call directly and assert the aggregation in
     * [health] -- same pattern as PumpCommHandler's `internal var bluetoothHandler`.
     */
    internal data class TargetHealth(var lastSuccessAtMs: Long? = null, var consecutiveFailures: Int = 0)

    private val targetLock = Any()
    // Populated lazily, one entry per applicationId the first time it actually records
    // an event -- NOT eagerly pre-populated from watchTargets at construction. An eager
    // pre-population would leave a permanent zero-failure entry for a target that has
    // never actually been recorded through (e.g. under a key that doesn't exactly match
    // what a later caller uses), silently pulling the aggregate's minOf down to 0 even
    // when the intended target genuinely never sent. Before any send, an empty map
    // correctly yields the same "nothing sent yet" default (null / 0) as before.
    private val targetHealth: MutableMap<String, TargetHealth> = LinkedHashMap()

    internal fun recordSendSuccess(applicationId: String) = synchronized(targetLock) {
        val t = targetHealth.getOrPut(applicationId) { TargetHealth() }
        t.lastSuccessAtMs = System.currentTimeMillis()
        t.consecutiveFailures = 0
    }

    internal fun recordSendFailure(applicationId: String) = synchronized(targetLock) {
        val t = targetHealth.getOrPut(applicationId) { TargetHealth() }
        t.consecutiveFailures += 1
    }

    internal fun recordSendFailureAllTargets() = synchronized(targetLock) {
        watchTargets.forEach { targetHealth.getOrPut(it.applicationId) { TargetHealth() }.consecutiveFailures += 1 }
    }

    /**
     * Current health snapshot for the Dart-side system-health surface. lastSuccessAtMs
     * is the most recent successful delivery to ANY target; consecutiveFailures is the
     * MINIMUM across targets, so it stays 0 as long as at least one target's most
     * recent send succeeded -- it only goes nonzero when EVERY target failed together,
     * which is a real send-path problem (SDK/BLE/device issue), not "most targets
     * aren't installed" (AC#1/#2/#3).
     */
    fun health(): Map<String, Any?> = synchronized(targetLock) {
        val states = targetHealth.values
        mapOf(
            "lastSuccessAtMs" to states.mapNotNull { it.lastSuccessAtMs }.maxOrNull(),
            "consecutiveFailures" to (states.minOfOrNull { it.consecutiveFailures } ?: 0),
        )
    }

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
                            recordSendSuccess(app.applicationId)
                        } else {
                            recordSendFailure(app.applicationId)
                        }
                        Log.d(TAG, "watch send ${app.applicationId} → $status")
                    }
                }
            }
            lastSentAtMs = now
            // These three catches are SDK-level failures before any per-app message was
            // even attempted (e.g. ciq.connectedDevices itself throwing) -- there is no
            // per-target result to attribute, so every target's streak advances together,
            // same as a genuinely down send path should.
        } catch (e: InvalidStateException) {
            recordSendFailureAllTargets()
            Log.i(TAG, "Connect IQ not in a sendable state", e)
        } catch (e: ServiceUnavailableException) {
            recordSendFailureAllTargets()
            Log.i(TAG, "Garmin Connect service unavailable", e)
        } catch (t: Throwable) {
            recordSendFailureAllTargets()
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
