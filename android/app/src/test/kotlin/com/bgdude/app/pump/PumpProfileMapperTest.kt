package com.bgdude.app.pump

import com.jwoglom.pumpx2.pump.messages.response.currentStatus.IDPSegmentResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.IDPSettingsResponse
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM unit tests for [PumpProfileMapper]. Real pumpx2 IDP objects; real org.json is on the
 * test classpath (see build.gradle) so the emitted therapy-profile JSON can be asserted.
 *
 * Constructor arg orders confirmed via `javap` against pumpx2-messages-1.9.0.jar:
 *  - IDPSettingsResponse(idpId, name, numberOfProfileSegments, insulinDuration, maxBolus,
 *                        carbEntry)
 *  - IDPSegmentResponse(idpId, segmentIndex, profileStartTime, profileBasalRate:Int(mU),
 *                       profileCarbRatio:Long(mU), profileTargetBG, profileISF, idpStatusId)
 */
class PumpProfileMapperTest {

    private fun settings(segments: Int) =
        IDPSettingsResponse(1, "Active", segments, 300, 25, true)

    private fun segment(
        index: Int,
        startMin: Int,
        basalMilliU: Int,
        carbRatioMilliU: Long,
        targetBG: Int,
        isf: Int,
        idpId: Int = 1,
    ) = IDPSegmentResponse(idpId, index, startMin, basalMilliU, carbRatioMilliU, targetBG, isf, 0)

    @Test
    fun complete_only_after_all_segments_arrive() {
        val mapper = PumpProfileMapper()
        assertEquals(1, mapper.onSettings(settings(2)))
        assertFalse("no segments yet", mapper.complete)

        mapper.onSegment(segment(0, 0, 850, 10_000L, 110, 50))
        assertFalse("1 of 2", mapper.complete)

        mapper.onSegment(segment(1, 720, 1000, 12_000L, 100, 45))
        assertTrue("2 of 2", mapper.complete)
    }

    @Test
    fun segment_from_a_different_idp_is_ignored() {
        val mapper = PumpProfileMapper()
        mapper.onSettings(settings(1))
        mapper.onSegment(segment(0, 0, 850, 10_000L, 110, 50, idpId = 99))
        assertFalse("wrong idp must not count", mapper.complete)

        mapper.onSegment(segment(0, 0, 850, 10_000L, 110, 50))
        assertTrue(mapper.complete)
    }

    @Test
    fun json_converts_milliunits_and_carries_profile_fields() {
        val mapper = PumpProfileMapper()
        mapper.onSettings(settings(2))
        mapper.onSegment(segment(0, 0, 850, 10_000L, 110, 50))
        mapper.onSegment(segment(1, 720, 1000, 12_000L, 100, 45))

        val json = JSONObject(mapper.toJson())
        // Profile-level fields.
        assertEquals(300, json.getInt("dia"))
        assertEquals(25.0, json.getDouble("maxBolus"), 1e-9)
        assertEquals(75, json.getInt("peak"))
        assertEquals("Active", json.getString("name"))

        val segs = json.getJSONArray("segments")
        assertEquals(2, segs.length())

        val s0 = segs.getJSONObject(0)
        assertEquals(0, s0.getInt("startMinuteOfDay"))
        // 850 mU/h → 0.85 U/h; 10000 mU/g → 10.0 g/U.
        assertEquals(0.85, s0.getDouble("basalUnitsPerHour"), 1e-9)
        assertEquals(10.0, s0.getDouble("carbRatio"), 1e-9)
        assertEquals(110.0, s0.getDouble("targetMgdl"), 1e-9)
        assertEquals(50.0, s0.getDouble("isf"), 1e-9)

        val s1 = segs.getJSONObject(1)
        assertEquals(720, s1.getInt("startMinuteOfDay"))
        assertEquals(1.0, s1.getDouble("basalUnitsPerHour"), 1e-9)
        assertEquals(12.0, s1.getDouble("carbRatio"), 1e-9)
        assertEquals(100.0, s1.getDouble("targetMgdl"), 1e-9)
        assertEquals(45.0, s1.getDouble("isf"), 1e-9)
    }
}
