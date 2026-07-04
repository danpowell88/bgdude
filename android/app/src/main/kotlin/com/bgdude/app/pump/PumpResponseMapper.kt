package com.bgdude.app.pump

import com.jwoglom.pumpx2.pump.messages.Message
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.ApiVersionResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.ControlIQIOBResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CurrentBasalStatusResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CurrentBatteryV1Response
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CurrentBatteryV2Response
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CurrentEGVGuiDataResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.InsulinStatusResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.LastBolusStatusV2Response

/**
 * Maps pumpx2 response objects onto the [MutableSnapshot]. Branches on concrete response
 * classes; because responses are versioned (V1/V2/V3) the handler picks the request
 * variant per `ApiVersionResponse`, and this mapper accepts whichever comes back.
 *
 * Read-only: only response classes appear here.
 */
object PumpResponseMapper {

    fun apply(message: Message, snapshot: MutableSnapshot) {
        when (message) {
            is CurrentBatteryV1Response ->
                snapshot.batteryPercent = message.currentBatteryPercent
            is CurrentBatteryV2Response ->
                snapshot.batteryPercent = message.currentBatteryPercent

            is InsulinStatusResponse ->
                snapshot.reservoirUnits = message.currentInsulinAmount.toDouble()

            is ControlIQIOBResponse -> {
                snapshot.iobUnits = message.mudaliarIOB / 1000.0 // milliunits → units
                snapshot.controlIqActive = true
            }

            is CurrentBasalStatusResponse ->
                snapshot.basalUnitsPerHour = message.currentBasalRate / 1000.0

            is CurrentEGVGuiDataResponse -> {
                snapshot.cgmMgdl = message.cgmReading
                snapshot.cgmTrend = mapTrend(message.trendRate)
                snapshot.cgmTimestampEpochMs =
                    message.timestampSeconds.toLong() * 1000L
            }

            is LastBolusStatusV2Response -> {
                snapshot.lastBolusUnits = message.deliveredVolume / 1000.0
                snapshot.lastBolusTimestampEpochMs =
                    message.timestamp.toLong() * 1000L
            }

            is ApiVersionResponse ->
                snapshot.apiVersion = "${message.majorVersion}.${message.minorVersion}"

            else -> { /* Unhandled response types are ignored (best-effort). */ }
        }
    }

    /** pumpx2 exposes trend as a rate; bucket it to the Dexcom arrow vocabulary. */
    private fun mapTrend(trendRate: Int): String = when {
        trendRate >= 30 -> "doubleUp"
        trendRate >= 20 -> "singleUp"
        trendRate >= 10 -> "fortyFiveUp"
        trendRate > -10 -> "flat"
        trendRate > -20 -> "fortyFiveDown"
        trendRate > -30 -> "singleDown"
        else -> "doubleDown"
    }
}
