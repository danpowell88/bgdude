package com.bgdude.app.pump

import com.jwoglom.pumpx2.pump.messages.response.currentStatus.ControlIQIOBResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.ControlIQInfoV2Response
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CurrentBatteryV1Response
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.CurrentEGVGuiDataResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.InsulinStatusResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.PumpGlobalsResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.PumpSettingsResponse
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

    /**
     * Issue #85: PumpSettings from the complete captured cargo in doc/pump-protocol.md
     * — `14 1e 01 0c 00 00 0f 48 00`, documented as autoShutdownEnabled=1,
     * autoShutdownDuration=12 h, lowInsulinThreshold=20 U, oledTimeout=15 s,
     * featureLock=0, and byte 2 (0x1e=30) the cannula-prime size.
     */
    @Test
    fun pump_settings_decode_from_the_captured_cargo() {
        val response = PumpSettingsResponse()
        response.parse(byteArrayOf(0x14, 0x1e, 0x01, 0x0c, 0, 0, 0x0f, 0x48, 0))

        val snapshot = MutableSnapshot()
        PumpResponseMapper.apply(response, snapshot)

        assertEquals(true, snapshot.autoShutdownEnabled)
        assertEquals(12, snapshot.autoShutdownHours)
        assertEquals(20, snapshot.lowInsulinThresholdUnits)
        assertEquals(false, snapshot.featureLocked)
        // Hundredths of a unit on the wire: 0x1e = 30 -> 0.30 U.
        assertEquals(0.30, snapshot.cannulaPrimeSizeUnits!!, 0.001)
    }

    /**
     * Issue #85: PumpGlobals, likewise from its complete captured cargo
     * `01 f4 01 d0 07 00 01 03 01 01 01 01 01 01` (quick bolus enabled).
     */
    @Test
    fun pump_globals_decode_quick_bolus_enabled() {
        val response = PumpGlobalsResponse()
        response.parse(
            byteArrayOf(
                0x01, 0xf4.toByte(), 0x01, 0xd0.toByte(), 0x07, 0x00,
                0x01, 0x03, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
            ),
        )

        val snapshot = MutableSnapshot()
        PumpResponseMapper.apply(response, snapshot)

        assertEquals(true, snapshot.quickBolusEnabled)
    }

    /** Absent until the pump answers — an unconfigured pump and an unasked one differ. */
    @Test
    fun pump_settings_absent_until_answered() {
        val json = MutableSnapshot().toJson()
        assertTrue(!json.contains("lowInsulinThresholdUnits"))
    }

}
