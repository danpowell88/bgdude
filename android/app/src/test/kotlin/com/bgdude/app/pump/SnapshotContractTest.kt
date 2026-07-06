package com.bgdude.app.pump

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Cross-language contract test (TASK-111): pins that MutableSnapshot.toJson() emits exactly
 * the field names/values the Dart parser expects. The same golden fixture is parsed by the
 * Dart side (test/contracts_test.dart) and checked in at test/contracts/.
 *
 * `timestampEpochMs` is System.currentTimeMillis() at serialize time, so it is normalized
 * to the golden's fixed value before comparison.
 */
class SnapshotContractTest {

    private val golden =
        """{"timestampEpochMs":1751800000000,"model":"UNKNOWN","batteryPercent":75,""" +
            """"isCharging":false,"reservoirUnits":120.5,"iobUnits":1.5,""" +
            """"basalUnitsPerHour":0.8,"controlIqActive":true,"closedLoopEnabled":true,""" +
            """"controlIqMode":"SLEEP","cgmMgdl":120,"cgmTrend":"flat",""" +
            """"cgmTimestampEpochMs":1751799900000,"lastBolusUnits":5.5,""" +
            """"lastBolusTimestampEpochMs":1751799000000,"apiVersion":"2.1",""" +
            """"firmwareVersion":"7.4","activeAlerts":["LOW_INSULIN"],""" +
            """"activeAlarms":["OCCLUSION"]}"""

    private fun goldenSnapshot() = MutableSnapshot().apply {
        model = PumpModel.UNKNOWN
        batteryPercent = 75
        isCharging = false
        reservoirUnits = 120.5
        iobUnits = 1.5
        basalUnitsPerHour = 0.8
        controlIqActive = true
        closedLoopEnabled = true
        controlIqMode = "SLEEP"
        cgmMgdl = 120
        cgmTrend = "flat"
        cgmTimestampEpochMs = 1751799900000L
        lastBolusUnits = 5.5
        lastBolusTimestampEpochMs = 1751799000000L
        apiVersion = "2.1"
        firmwareVersion = "7.4"
        activeAlerts = mutableListOf("LOW_INSULIN")
        activeAlarms = mutableListOf("OCCLUSION")
    }

    private fun normalizeTimestamp(json: String) =
        json.replace(Regex("\"timestampEpochMs\":\\d+"), "\"timestampEpochMs\":1751800000000")

    @Test
    fun toJson_matches_the_golden_contract() {
        assertEquals(golden, normalizeTimestamp(goldenSnapshot().toJson()))
    }

    @Test
    fun golden_constant_matches_the_checked_in_fixture_when_reachable() {
        // Unit tests run with working dir = android/app, so the repo fixture is two up.
        val file = File("../../test/contracts/mutable_snapshot_golden.json")
        if (file.exists()) {
            assertEquals(golden, file.readText().trim())
        }
    }
}
