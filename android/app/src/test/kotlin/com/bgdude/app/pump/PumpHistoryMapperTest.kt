package com.bgdude.app.pump

import com.jwoglom.pumpx2.pump.messages.response.historyLog.AlarmActivatedHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.AlarmClearedHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.AlertActivatedHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.BasalRateChangeHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.BolusCompletedHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.CannulaFilledHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.CarbEnteredHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.CartridgeFilledHistoryLog
import com.jwoglom.pumpx2.pump.messages.response.historyLog.CgmDataGxHistoryLog
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * JVM unit tests for [PumpHistoryMapper]. These construct real pumpx2 history-log objects
 * (pumpx2-messages is on the test compile classpath) and assert the mapped map field-by-field.
 *
 * Constructor arg orders confirmed via `javap` against pumpx2-messages-1.9.0.jar. Every
 * HistoryLog subclass prefixes its own fields with the base (long pumpTimeSec, long seqNum):
 *  - BolusCompletedHistoryLog(pumpTimeSec, seq, completionStatusId, bolusId, iob,
 *                             insulinDelivered, insulinRequested)
 *  - CgmDataGxHistoryLog(pumpTimeSec, seq, status, type, rate, rssi, value, timestamp,
 *                        transmitterTimestamp)  ← maps `timestamp`, NOT `pumpTimeSec`
 *  - BasalRateChangeHistoryLog(pumpTimeSec, seq, commandBasalRate, baseBasalRate,
 *                             maxBasalRate, insulinDeliveryProfile, changeTypeId)
 *  - CarbEnteredHistoryLog(pumpTimeSec, seq, carbs)
 *  - CartridgeFilledHistoryLog(pumpTimeSec, seq, insulinDisplay, insulinActual)
 *  - CannulaFilledHistoryLog(pumpTimeSec, seq, primeSize)
 *  - AlarmActivatedHistoryLog(pumpTimeSec, seq, alarmId)
 *  - AlertActivatedHistoryLog(pumpTimeSec, seq, alertId)
 */
class PumpHistoryMapperTest {

    /** Tandem pump epoch (2008-01-01T00:00:00Z) in ms — mirrors the mapper's constant. */
    private val tandemEpochMs = 1_199_145_600_000L

    private fun expectedEpoch(pumpTimeSec: Long) = tandemEpochMs + pumpTimeSec * 1000L

    @Test
    fun bolus_maps_units_and_pumpTime_epoch() {
        val map = PumpHistoryMapper.map(
            BolusCompletedHistoryLog(1000L, 1L, 0, 0, 0f, 5.5f, 5.5f),
        )!!
        assertEquals("bolus", map["type"])
        assertEquals(expectedEpoch(1000L), map["epochMs"])
        assertEquals(5.5, map["units"] as Double, 1e-6)
    }

    @Test
    fun cgm_uses_the_message_timestamp_field_not_pumpTimeSec() {
        // The known divergence: CgmDataGx keys off `timestamp`, every other type off
        // `pumpTimeSec`. Give them DIFFERENT values so the test pins which one is used.
        val pumpTimeSec = 999L
        val timestamp = 2000L
        val map = PumpHistoryMapper.map(
            CgmDataGxHistoryLog(pumpTimeSec, 1L, 0, 0, 0, 0, 120, timestamp, 0L),
        )!!
        assertEquals("cgm", map["type"])
        assertEquals(120, map["mgdl"])
        // Must be the timestamp-derived epoch, and must NOT be the pumpTimeSec-derived one.
        assertEquals(expectedEpoch(timestamp), map["epochMs"])
        assertEquals(false, map["epochMs"] == expectedEpoch(pumpTimeSec))
    }

    @Test
    fun basal_change_maps_command_rate() {
        val map = PumpHistoryMapper.map(
            BasalRateChangeHistoryLog(1500L, 1L, 0.85f, 0f, 0f, 0, 0),
        )!!
        assertEquals("basalChange", map["type"])
        assertEquals(expectedEpoch(1500L), map["epochMs"])
        assertEquals(0.85, map["units"] as Double, 1e-4)
    }

    @Test
    fun carb_maps_grams() {
        val map = PumpHistoryMapper.map(CarbEnteredHistoryLog(1200L, 1L, 45f))!!
        assertEquals("carb", map["type"])
        assertEquals(expectedEpoch(1200L), map["epochMs"])
        assertEquals(45.0, map["carbsGrams"] as Double, 1e-6)
    }

    @Test
    fun cartridge_filled_maps_insulin_actual() {
        val map = PumpHistoryMapper.map(CartridgeFilledHistoryLog(1300L, 1L, 0L, 200f))!!
        assertEquals("cartridgeFilled", map["type"])
        assertEquals(expectedEpoch(1300L), map["epochMs"])
        assertEquals(200.0, map["units"] as Double, 1e-6)
    }

    @Test
    fun cannula_filled_maps_prime_size() {
        val map = PumpHistoryMapper.map(CannulaFilledHistoryLog(1400L, 1L, 0.5f))!!
        assertEquals("cannulaFilled", map["type"])
        assertEquals(expectedEpoch(1400L), map["epochMs"])
        assertEquals(0.5, map["primeSize"] as Double, 1e-6)
    }

    @Test
    fun alarm_maps_id_and_epoch() {
        val map = PumpHistoryMapper.map(AlarmActivatedHistoryLog(1600L, 1L, 42L))!!
        assertEquals("alarm", map["type"])
        assertEquals(expectedEpoch(1600L), map["epochMs"])
        assertEquals(42L, map["id"])
    }

    @Test
    fun alert_maps_id_and_epoch() {
        val map = PumpHistoryMapper.map(AlertActivatedHistoryLog(1700L, 1L, 7L))!!
        assertEquals("alert", map["type"])
        assertEquals(expectedEpoch(1700L), map["epochMs"])
        assertEquals(7L, map["id"])
    }

    @Test
    fun unmapped_type_returns_null() {
        // AlarmClearedHistoryLog is a real HistoryLog subclass the mapper does not handle.
        assertNull(PumpHistoryMapper.map(AlarmClearedHistoryLog(1800L, 1L, 42L)))
    }
}
