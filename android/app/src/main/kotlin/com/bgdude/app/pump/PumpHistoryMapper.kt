package com.bgdude.app.pump

import com.jwoglom.pumpx2.pump.messages.response.historyLog.AlarmActivatedHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.AlertActivatedHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.BasalRateChangeHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.BolusCompletedHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.CannulaFilledHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.CarbEnteredHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.CartridgeFilledHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.CgmDataGxHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.HistoryLog

/**
 * Maps decoded pump History Log entries to the compact JSON-able maps the Dart
 * [HistoryBackfillService] expects (keys: epochMs, type, units/mgdl/carbsGrams).
 *
 * pumpx2's history decoding is partial and this has not been validated against real
 * hardware — only a handful of high-value entry types are mapped; anything else returns
 * null and is skipped. Timestamps are Tandem-epoch seconds (2008-01-01) → Unix ms.
 *
 * Input is a decoded [HistoryLog] entry — the pump delivers these inside a
 * HistoryLogStreamResponse, so callers must unpack `getHistoryLogs()` and map each entry
 * (the entries are NOT themselves Messages).
 */
object PumpHistoryMapper {

    private const val TANDEM_EPOCH_MS = 1_199_145_600_000L

    fun map(message: HistoryLog): Map<String, Any?>? = when (message) {
        is BolusCompletedHistoryLog -> mapOf(
            "epochMs" to epochMs(message),
            "type" to "bolus",
            "units" to message.insulinDelivered.toDouble(),
        )
        is CgmDataGxHistoryLog -> mapOf(
            "epochMs" to TANDEM_EPOCH_MS + message.timestamp * 1000L,
            "type" to "cgm",
            "mgdl" to message.value,
        )
        is BasalRateChangeHistoryLog -> mapOf(
            "epochMs" to epochMs(message),
            "type" to "basalChange",
            "units" to message.commandBasalRate.toDouble(),
        )
        // Carb entries logged on the pump — fills the app's carb history.
        is CarbEnteredHistoryLog -> mapOf(
            "epochMs" to epochMs(message),
            "type" to "carb",
            "carbsGrams" to message.carbs.toDouble(),
        )
        // Site/cartridge changes → drives infusion-set & reservoir age reminders.
        is CartridgeFilledHistoryLog -> mapOf(
            "epochMs" to epochMs(message),
            "type" to "cartridgeFilled",
            "units" to message.insulinActual.toDouble(),
        )
        is CannulaFilledHistoryLog -> mapOf(
            "epochMs" to epochMs(message),
            "type" to "cannulaFilled",
            "primeSize" to message.primeSize.toDouble(),
        )
        // Alarms (higher severity) and alerts (informational) as a timeline.
        is AlarmActivatedHistoryLog -> mapOf(
            "epochMs" to epochMs(message),
            "type" to "alarm",
            "id" to message.alarmId,
            "name" to (runCatching { message.alarmResponseType?.name }.getOrNull()
                ?: message.alarmId.toString()),
        )
        is AlertActivatedHistoryLog -> mapOf(
            "epochMs" to epochMs(message),
            "type" to "alert",
            "id" to message.alertId,
            "name" to (runCatching { message.alertResponseType?.name }.getOrNull()
                ?: message.alertId.toString()),
        )
        else -> null
    }

    private fun epochMs(log: HistoryLog): Long = TANDEM_EPOCH_MS + log.pumpTimeSec * 1000L
}
