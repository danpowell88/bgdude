package com.bgdude.app.pump

import com.jwoglom.pumpx2.pump.messages.response.currentStatus.IDPSegmentResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.IDPSettingsResponse
import org.json.JSONArray
import org.json.JSONObject

/**
 * Accumulates the active Insulin Delivery Profile (IDP) as its settings + per-segment
 * responses stream in, and produces a therapy-profile JSON the Dart side turns into
 * TherapySettings (basal / ISF / carb ratio / target per time-of-day segment).
 *
 * pumpx2 unit conventions (from the message classes): basal rate and carb ratio are
 * milli-units (×1000); ISF and target are mg/dL; segment start is minutes since midnight.
 * Best-effort — not validated on hardware.
 */
class PumpProfileMapper {

    private var idpId: Int = -1
    private var expectedSegments: Int = 0
    private var name: String = ""
    private var insulinDurationMin: Int = 360
    private var maxBolus: Int = 25
    private val segments = mutableListOf<JSONObject>()

    /** Begin accumulating for [settings]'s profile; returns the idpId to fetch segments for. */
    fun onSettings(settings: IDPSettingsResponse): Int {
        idpId = settings.idpId
        expectedSegments = settings.numberOfProfileSegments
        name = settings.name ?: ""
        insulinDurationMin = settings.insulinDuration
        maxBolus = settings.maxBolus
        segments.clear()
        return idpId
    }

    fun onSegment(seg: IDPSegmentResponse) {
        if (seg.idpId != idpId) return
        segments.add(
            JSONObject()
                .put("startMinuteOfDay", seg.profileStartTime)
                .put("basalUnitsPerHour", seg.profileBasalRate / 1000.0)
                .put("carbRatio", seg.profileCarbRatio / 1000.0)
                .put("targetMgdl", seg.profileTargetBG.toDouble())
                .put("isf", seg.profileISF.toDouble()),
        )
    }

    /** True once every segment for the profile has arrived. */
    val complete: Boolean
        get() = expectedSegments > 0 && segments.size >= expectedSegments

    /** The therapy-profile JSON matching the Dart TherapySettings.fromJson shape. */
    fun toJson(): String = JSONObject()
        .put("segments", JSONArray(segments))
        .put("dia", insulinDurationMin)
        .put("maxBolus", maxBolus.toDouble())
        .put("peak", 75)
        .put("name", name)
        .toString()
}
