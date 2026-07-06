package com.bgdude.app.pump

import com.jwoglom.pumpx2.pump.messages.response.currentStatus.ControlIQIOBResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.ControlIQInfoV2Response
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CurrentBatteryV1Response
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CurrentEGVGuiDataResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.InsulinStatusResponse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM unit tests for [PumpResponseMapper]. These construct real pumpx2 response objects
 * (pumpx2-messages is on the test compile classpath) and assert the mapper writes the
 * expected [MutableSnapshot] fields.
 *
 * Constructor arg orders were confirmed via `javap` against pumpx2-messages-1.9.0.jar:
 *  - CurrentBatteryV1Response(int abc, int ibc)
 *  - InsulinStatusResponse(int currentInsulinAmount, int isEstimate, int insulinLowAmount)
 *  - ControlIQIOBResponse(long mudaliarIOB, long timeRemainingSeconds,
 *                         long mudaliarTotalIOB, long swan6hrIOB, int iobType)
 *  - CurrentEGVGuiDataResponse(long bgReadingTimestampSeconds, int cgmReading,
 *                             int egvStatusId, int trendRate)
 */
class PumpResponseMapperTest {

    /** Tandem pump epoch (2008-01-01T00:00:00Z) in ms — mirrors the mapper's constant. */
    private val tandemEpochMs = 1_199_145_600_000L

    @Test
    fun battery_v1_uses_ibc_not_abc() {
        val snapshot = MutableSnapshot()
        // (abc = 50, ibc = 75) — the mapper must read the ibc field the pump UI shows.
        PumpResponseMapper.apply(CurrentBatteryV1Response(50, 75), snapshot)

        assertEquals(75, snapshot.batteryPercent)
    }

    @Test
    fun insulin_status_sets_reservoir_units() {
        val snapshot = MutableSnapshot()
        // currentInsulinAmount = 150 (units), isEstimate = 0, insulinLowAmount = 10.
        PumpResponseMapper.apply(InsulinStatusResponse(150, 0, 10), snapshot)

        assertNotNull(snapshot.reservoirUnits)
        assertEquals(150.0, snapshot.reservoirUnits!!, 1e-9)
    }

    @Test
    fun controliq_iob_divides_milliunits_by_1000() {
        val snapshot = MutableSnapshot()
        // iobType = 0 => MUDALIAR, so getPumpDisplayedIOB() returns mudaliarIOB (1500 mU).
        val response = ControlIQIOBResponse(
            /* mudaliarIOB */ 1500L,
            /* timeRemainingSeconds */ 0L,
            /* mudaliarTotalIOB */ 0L,
            /* swan6hrIOB */ 0L,
            /* iobType */ 0,
        )
        PumpResponseMapper.apply(response, snapshot)

        assertNotNull(snapshot.iobUnits)
        assertEquals(1.5, snapshot.iobUnits!!, 1e-9)
        assertEquals(true, snapshot.controlIqActive)
    }

    @Test
    fun controliq_info_maps_closed_loop_and_user_mode() {
        val snapshot = MutableSnapshot()
        // Args (confirmed via javap): closedLoopEnabled, weight, weightUnitId,
        // totalDailyInsulin, currentUserModeTypeId (SLEEP=1), byte6, byte7, byte8,
        // controlStateType, exerciseChoice, exerciseDuration, exerciseTimeRemaining.
        val response = ControlIQInfoV2Response(
            /* closedLoopEnabled */ true,
            /* weight */ 70,
            /* weightUnitId */ 0,
            /* totalDailyInsulin */ 500,
            /* currentUserModeTypeId */ 1,
            0, 0, 0, 0, 0,
            /* exerciseDuration */ 0L,
            /* exerciseTimeRemaining */ 0L,
        )
        PumpResponseMapper.apply(response, snapshot)

        // The mapper must faithfully mirror the response's own decoded values.
        assertEquals(true, snapshot.closedLoopEnabled)
        assertEquals(true, snapshot.controlIqActive)
        assertEquals(response.currentUserModeType.name, snapshot.controlIqMode)
    }

    @Test
    fun egv_sets_reading_trend_and_timestamp() {
        val snapshot = MutableSnapshot()
        val bgTimestampSeconds = 500_000_000L
        // trendRate = 35 (>= 30) => strongly rising => "doubleUp".
        val response = CurrentEGVGuiDataResponse(
            /* bgReadingTimestampSeconds */ bgTimestampSeconds,
            /* cgmReading */ 120,
            /* egvStatusId */ 0,
            /* trendRate */ 35,
        )
        PumpResponseMapper.apply(response, snapshot)

        assertEquals(120, snapshot.cgmMgdl)
        assertEquals("doubleUp", snapshot.cgmTrend)
        assertNotNull(snapshot.cgmTimestampEpochMs)
        // Timestamp is Tandem epoch + seconds*1000, so strictly after the Tandem epoch.
        assertTrue(snapshot.cgmTimestampEpochMs!! > tandemEpochMs)
        assertEquals(tandemEpochMs + bgTimestampSeconds * 1000L, snapshot.cgmTimestampEpochMs)
    }

    @Test
    fun egv_trend_buckets_flat_for_small_rate() {
        val snapshot = MutableSnapshot()
        val response = CurrentEGVGuiDataResponse(1L, 100, 0, 0)
        PumpResponseMapper.apply(response, snapshot)

        assertEquals("flat", snapshot.cgmTrend)
    }

    @Test
    fun max_bolus_setting_converts_milliunits_to_units() {
        val snapshot = MutableSnapshot()
        // GlobalMaxBolusSettingsResponse(maxBolus, maxBolusDefault) in milli-units.
        PumpResponseMapper.apply(
            com.jwoglom.pumpx2.pump.messages.response.currentStatus
                .GlobalMaxBolusSettingsResponse(15000, 25000),
            snapshot,
        )
        assertNotNull(snapshot.maxBolusUnits)
        assertEquals(15.0, snapshot.maxBolusUnits!!, 1e-9)
    }

    @Test
    fun basal_limit_setting_converts_milliunits_per_hour() {
        val snapshot = MutableSnapshot()
        PumpResponseMapper.apply(
            com.jwoglom.pumpx2.pump.messages.response.currentStatus
                .BasalLimitSettingsResponse(3000L, 15000L),
            snapshot,
        )
        assertNotNull(snapshot.maxBasalUnitsPerHour)
        assertEquals(3.0, snapshot.maxBasalUnitsPerHour!!, 1e-9)
    }

    @Test
    fun unhandled_message_leaves_snapshot_untouched() {
        val snapshot = MutableSnapshot()
        // ApiVersionResponse is handled, but battery is left null by an EGV-only run;
        // assert an unrelated field stays null after an insulin-only mapping.
        PumpResponseMapper.apply(InsulinStatusResponse(100, 0, 5), snapshot)

        assertEquals(null, snapshot.cgmMgdl)
        assertEquals(null, snapshot.batteryPercent)
    }
}
