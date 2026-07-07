package com.bgdude.app.pump

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tests for [MutableSnapshot.toJson]. TASK-173: the serializer is hand-rolled, so every
 * assertion decodes the output through a REAL JSON parser (org.json on the test
 * classpath) and asserts on decoded fields — substring checks let an escaping/comma bug
 * ship invalid JSON that only failed at runtime on-device.
 */
class MutableSnapshotTest {

    private fun decode(snapshot: MutableSnapshot): JSONObject {
        val json = snapshot.toJson()
        // JSONObject throws on malformed input — this line IS the validity assertion.
        return JSONObject(json)
    }

    @Test
    fun toJson_decodes_with_set_fields_intact() {
        val obj = decode(MutableSnapshot().apply {
            cgmMgdl = 120
            iobUnits = 1.5
            batteryPercent = 88
            cgmTrend = "singleUp"
        })

        assertEquals(120, obj.getInt("cgmMgdl"))
        assertEquals(1.5, obj.getDouble("iobUnits"), 1e-9)
        assertEquals(88, obj.getInt("batteryPercent"))
        assertEquals("singleUp", obj.getString("cgmTrend"))
        // model always emitted (non-null enum), timestamp injected, schema versioned.
        assertEquals("UNKNOWN", obj.getString("model"))
        assertTrue(obj.getLong("timestampEpochMs") > 0)
        assertEquals(MutableSnapshot.SCHEMA_VERSION, obj.getInt("schemaVersion"))
    }

    @Test
    fun toJson_omits_null_fields_as_decoded_keys() {
        val obj = decode(MutableSnapshot().apply { batteryPercent = 42 })

        assertEquals(42, obj.getInt("batteryPercent"))
        // Unset fields must be ABSENT as keys after decode, not null-valued.
        assertFalse(obj.has("cgmMgdl"))
        assertFalse(obj.has("reservoirUnits"))
        assertFalse(obj.has("lastBolusUnits"))
        assertFalse(obj.has("isCharging"))
    }

    @Test
    fun toJson_survives_quotes_in_string_values() {
        val obj = decode(MutableSnapshot().apply { apiVersion = "2.\"5\"" })
        // Round-trip through the parser: the decoded value carries the raw quotes.
        assertEquals("2.\"5\"", obj.getString("apiVersion"))
    }

    @Test
    fun toJson_decodes_active_alerts_and_alarms_as_arrays() {
        val obj = decode(MutableSnapshot().apply {
            batteryPercent = 50
            activeAlerts = mutableListOf("LOW_POWER_ALERT", "CGM_SIGNAL_LOSS")
            activeAlarms = mutableListOf("LOW_INSULIN_ALARM")
        })

        val alerts = obj.getJSONArray("activeAlerts")
        assertEquals(2, alerts.length())
        assertEquals("LOW_POWER_ALERT", alerts.getString(0))
        assertEquals("CGM_SIGNAL_LOSS", alerts.getString(1))
        val alarms = obj.getJSONArray("activeAlarms")
        assertEquals(1, alarms.length())
        assertEquals("LOW_INSULIN_ALARM", alarms.getString(0))
    }

    @Test
    fun toJson_decodes_charging_state_when_set() {
        val charging = decode(MutableSnapshot().apply {
            batteryPercent = 45
            isCharging = true
        })
        assertEquals(45, charging.getInt("batteryPercent"))
        assertTrue(charging.getBoolean("isCharging"))

        // Unset → omitted (V1 pumps don't report it).
        val noCharge = decode(MutableSnapshot().apply { batteryPercent = 45 })
        assertFalse(noCharge.has("isCharging"))
    }

    @Test
    fun toJson_omits_empty_alert_arrays() {
        val obj = decode(MutableSnapshot().apply { batteryPercent = 50 })
        assertFalse(obj.has("activeAlerts"))
        assertFalse(obj.has("activeAlarms"))
    }

    @Test
    fun toJson_decodes_regardless_of_which_field_is_last() {
        // Fields are comma-joined; any combination must stay parseable (the Dart
        // side jsonDecodes this stream). decode() throws on a dangling ",}".
        val a = decode(MutableSnapshot().apply {
            batteryPercent = 10
            iobUnits = 0.25
        })
        assertEquals(0.25, a.getDouble("iobUnits"), 1e-9)

        val b = decode(MutableSnapshot().apply {
            batteryPercent = 10
            firmwareVersion = "1.2.3"
        })
        assertEquals("1.2.3", b.getString("firmwareVersion"))
    }
}
