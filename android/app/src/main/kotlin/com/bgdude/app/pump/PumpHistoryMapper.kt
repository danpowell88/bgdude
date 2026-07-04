package com.bgdude.app.pump

import com.jwoglom.pumpx2.pump.messages.Message
import com.jwoglom.pumpx2.pump.messages.response.historyLog.BasalRateChangeHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.BolusCompletedHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.CgmDataGxHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.HistoryLog

/**
 * Maps decoded pump History Log entries to the compact JSON-able maps the Dart
 * [HistoryBackfillService] expects (keys: epochMs, type, units/mgdl/carbsGrams).
 *
 * pumpx2's history decoding is partial and this has not been validated against real
 * hardware — only a handful of high-value entry types are mapped; anything else returns
 * null and is skipped. Timestamps are Tandem-epoch seconds (2008-01-01) → Unix ms.
 */
object PumpHistoryMapper {

    private const val TANDEM_EPOCH_MS = 1_199_145_600_000L

    fun map(message: Message): Map<String, Any?>? = when (message) {
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
        else -> null
    }

    private fun epochMs(log: HistoryLog): Long = TANDEM_EPOCH_MS + log.pumpTimeSec * 1000L
}
