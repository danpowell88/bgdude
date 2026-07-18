package com.bgdude.app.pump

import com.jwoglom.pumpx2.pump.messages.Message
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.AlarmStatusResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.AlertStatusResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.ApiVersionResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.ControlIQIOBResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.ControlIQInfoAbstractResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.ControlIQInfoV1Response
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.ControlIQInfoV2Response
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.BasalLimitSettingsResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CurrentBasalStatusResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.GlobalMaxBolusSettingsResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CurrentBatteryV1Response
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CurrentBatteryV2Response
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CGMGlucoseAlertSettingsResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CGMHardwareInfoResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CurrentEGVGuiDataResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.InsulinStatusResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.LastBolusStatusV2Response
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.PumpVersionResponse

/**
 * Maps pumpx2 response objects onto the [MutableSnapshot]. Branches on concrete response
 * classes; because responses are versioned (V1/V2/V3) the handler picks the request
 * variant per `ApiVersionResponse`, and this mapper accepts whichever comes back.
 *
 * Read-only: only response classes appear here.
 */
object PumpResponseMapper {

    /** Tandem pump timestamps are seconds since 2008-01-01T00:00:00Z. */
    private const val TANDEM_EPOCH_MS = 1_199_145_600_000L

    fun apply(message: Message, snapshot: MutableSnapshot) {
        when (message) {
            // Ibc (internal battery capacity) is the value the pump UI shows as %.
            // Issue #90: CGM diagnostics. The transmitter id arrives as ASCII bytes;
            // pumpx2 has already decoded it to a String by this point.
            is CGMHardwareInfoResponse ->
                snapshot.cgmTransmitterId = message.hardwareInfoString?.trim()?.ifEmpty { null }

            // The pump's OWN alert thresholds, mirrored so the app can explain a
            // divergence rather than leaving the user to wonder why only one alerted.
            // `enabled` is an int on the wire; anything non-zero means on.
            is CGMGlucoseAlertSettingsResponse -> {
                snapshot.cgmHighAlertMgdl = message.highGlucoseAlertThreshold
                snapshot.cgmLowAlertMgdl = message.lowGlucoseAlertThreshold
                snapshot.cgmHighAlertEnabled = message.highGlucoseAlertEnabled != 0
                snapshot.cgmLowAlertEnabled = message.lowGlucoseAlertEnabled != 0
            }
            is CurrentBatteryV1Response ->
                snapshot.batteryPercent = message.currentBatteryIbc
            is CurrentBatteryV2Response -> {
                snapshot.batteryPercent = message.currentBatteryIbc
                // V2 also reports charging state — essential for drain estimation (a
                // charge resets the discharge slope). V1 pumps leave this null.
                snapshot.isCharging = message.isCharging
            }

            is InsulinStatusResponse ->
                snapshot.reservoirUnits = message.currentInsulinAmount.toDouble()

            // TASK-72: the pump's own safety limits (milli-units), shown and used to cap the
            // advisor so it never suggests more than the pump would allow.
            is GlobalMaxBolusSettingsResponse ->
                snapshot.maxBolusUnits = message.maxBolus / 1000.0

            is BasalLimitSettingsResponse ->
                snapshot.maxBasalUnitsPerHour = message.basalLimit / 1000.0

            is ControlIQIOBResponse -> {
                snapshot.iobUnits = message.pumpDisplayedIOB / 1000.0 // milliunits
                snapshot.controlIqActive = true
            }

            // Control-IQ info: whether the closed loop is on and the current user mode
            // (Standard / Sleep / Exercise). Control-IQ changes basal automatically and,
            // in Standard/Exercise, delivers automatic correction boluses — the analytics
            // layer needs this to avoid double-correcting and to tighten forecasts.
            is ControlIQInfoAbstractResponse -> {
                // getCurrentUserModeType() is public on the abstract response, but the
                // closed-loop flag only has a public getter on the concrete V1/V2 types
                // (the abstract field is package-private), so read it per-subclass.
                val closedLoop = when (message) {
                    is ControlIQInfoV1Response -> message.closedLoopEnabled
                    is ControlIQInfoV2Response -> message.closedLoopEnabled
                    else -> null
                }
                snapshot.closedLoopEnabled = closedLoop
                snapshot.controlIqMode = message.currentUserModeType?.name
                if (closedLoop == true) snapshot.controlIqActive = true
            }

            is CurrentBasalStatusResponse ->
                snapshot.basalUnitsPerHour = message.currentBasalRate / 1000.0

            is CurrentEGVGuiDataResponse -> {
                snapshot.cgmMgdl = message.cgmReading
                snapshot.cgmTrend = mapTrend(message.trendRate)
                snapshot.cgmTimestampEpochMs =
                    TANDEM_EPOCH_MS + message.bgReadingTimestampSeconds * 1000L
            }

            is LastBolusStatusV2Response -> {
                snapshot.lastBolusUnits = message.deliveredVolume / 1000.0
                snapshot.lastBolusTimestampEpochMs =
                    message.timestampInstant.toEpochMilli()
            }

            is ApiVersionResponse ->
                snapshot.apiVersion = "${message.majorVersion}.${message.minorVersion}"

            // Pump firmware (ARM software version). Auto-sent by the base handler on
            // connect, and re-requested with the status poll.
            is PumpVersionResponse ->
                snapshot.firmwareVersion = message.armSwVer.toString()

            // Active pump alerts (informational) and alarms (higher severity). Each
            // response carries the full current set, so replace rather than append.
            is AlertStatusResponse ->
                snapshot.activeAlerts = message.alerts.map { it.name }.toMutableList()
            is AlarmStatusResponse ->
                snapshot.activeAlarms = message.alarms.map { it.name }.toMutableList()

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
