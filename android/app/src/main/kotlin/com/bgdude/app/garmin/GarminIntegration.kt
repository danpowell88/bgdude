package com.bgdude.app.garmin

import android.content.Context
import android.util.Log
import org.json.JSONObject

/**
 * The single hook the pump service calls to fan snapshots out to the Garmin watch.
 * Owns a lazily-initialised [GarminSender]; translation from the snapshot JSON
 * (produced by MutableSnapshot.toJson()) to the compact watch payload happens here so
 * the pump code stays watch-agnostic.
 */
object GarminIntegration {

    private const val TAG = "GarminIntegration"

    private var sender: GarminSender? = null
    private var lastBg: Int = -1

    fun init(context: Context) {
        if (sender == null) {
            sender = GarminSender(context.applicationContext).also { it.initialize() }
        }
    }

    /** Called from PumpService.onSnapshotUpdated with the snapshot JSON. */
    fun onSnapshot(snapshotJson: String) {
        val s = sender ?: return
        try {
            val json = JSONObject(snapshotJson)
            val bg = json.optInt("cgmMgdl", -1)
            if (bg == -1) return
            val cgmTs = json.optLong("cgmTimestampEpochMs", 0L)
            val delta = if (lastBg != -1) bg - lastBg else 0
            lastBg = bg

            val payload = mutableMapOf<String, Any?>(
                "bg" to bg,
                "trend" to json.optString("cgmTrend", "unknown"),
                "delta" to delta, // mg/dL signed; watch converts to display unit
                "ageSec" to if (cgmTs > 0) {
                    ((System.currentTimeMillis() - cgmTs) / 1000L).toInt()
                } else {
                    -1
                },
                "iob" to json.optDouble("iobUnits", -1.0),
                "unit" to "mmol",
            )
            if (json.has("batteryPercent")) {
                payload["battery"] = json.optInt("batteryPercent")
            }
            if (json.has("reservoirUnits")) {
                payload["reservoir"] = json.optDouble("reservoirUnits")
            }
            s.send(payload)
        } catch (t: Throwable) {
            // Malformed snapshot — skip; never destabilise the pump path, but leave a
            // trace so a stopped watch feed is diagnosable.
            Log.i(TAG, "Skipped malformed snapshot for the watch", t)
        }
    }

    fun shutdown() {
        sender?.shutdown()
        sender = null
    }
}
