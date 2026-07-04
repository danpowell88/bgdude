package com.bgdude.app.garmin

import android.content.Context
import org.json.JSONObject

/**
 * The single hook the pump service calls to fan snapshots out to the Garmin watch.
 * Owns a lazily-initialised [GarminSender]; translation from the snapshot JSON
 * (produced by MutableSnapshot.toJson()) to the compact watch payload happens here so
 * the pump code stays watch-agnostic.
 */
object GarminIntegration {

    private var sender: GarminSender? = null

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
            val cgmTs = json.optLong("cgmTimestampEpochMs", 0L)
            val payload = mapOf(
                "bg" to json.optInt("cgmMgdl", -1),
                "trend" to json.optString("cgmTrend", "unknown"),
                "ageSec" to if (cgmTs > 0) {
                    ((System.currentTimeMillis() - cgmTs) / 1000L).toInt()
                } else {
                    -1
                },
                "iob" to json.optDouble("iobUnits", -1.0),
                "unit" to "mmol",
            )
            if (payload["bg"] != -1) s.send(payload)
        } catch (_: Throwable) {
            // Malformed snapshot — skip; never destabilise the pump path.
        }
    }

    fun shutdown() {
        sender?.shutdown()
        sender = null
    }
}
