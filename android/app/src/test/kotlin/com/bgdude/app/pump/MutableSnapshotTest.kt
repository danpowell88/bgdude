package com.bgdude.app.pump

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tests for [MutableSnapshot.toJson]. The serializer is hand-rolled (no org.json), so we
 * verify structure by substring — the emitted JSON is flat and simple.
 */
class MutableSnapshotTest {

    @Test
    fun toJson_emits_wellformed_object_with_set_fields() {
        val snapshot = MutableSnapshot().apply {
            cgmMgdl = 120
            iobUnits = 1.5
            batteryPercent = 88
            cgmTrend = "singleUp"
        }
        val json = snapshot.toJson()

        assertTrue("should be a JSON object", json.startsWith("{") && json.endsWith("}"))
        assertTrue(json, json.contains("\"cgmMgdl\":120"))
        assertTrue(json, json.contains("\"iobUnits\":1.5"))
        assertTrue(json, json.contains("\"batteryPercent\":88"))
        assertTrue(json, json.contains("\"cgmTrend\":\"singleUp\""))
        // model always emitted (non-null enum) and timestamp injected.
        assertTrue(json, json.contains("\"model\":\"UNKNOWN\""))
        assertTrue(json, json.contains("\"timestampEpochMs\":"))
    }

    @Test
    fun toJson_omits_null_fields() {
        val snapshot = MutableSnapshot().apply { batteryPercent = 42 }
        val json = snapshot.toJson()

        assertTrue(json, json.contains("\"batteryPercent\":42"))
        // Unset numeric/string fields must not appear at all.
        assertFalse(json, json.contains("cgmMgdl"))
        assertFalse(json, json.contains("reservoirUnits"))
        assertFalse(json, json.contains("lastBolusUnits"))
    }

    @Test
    fun toJson_escapes_quotes_in_string_values() {
        val snapshot = MutableSnapshot().apply { apiVersion = "2.\"5\"" }
        val json = snapshot.toJson()

        // Embedded quotes are backslash-escaped so the object stays parseable.
        assertTrue(json, json.contains("\"apiVersion\":\"2.\\\"5\\\"\""))
    }

    @Test
    fun toJson_emits_active_alerts_and_alarms_as_arrays() {
        val snapshot = MutableSnapshot().apply {
            batteryPercent = 50
            activeAlerts = mutableListOf("LOW_POWER_ALERT", "CGM_SIGNAL_LOSS")
            activeAlarms = mutableListOf("LOW_INSULIN_ALARM")
        }
        val json = snapshot.toJson()

        assertTrue(json, json.contains(
            "\"activeAlerts\":[\"LOW_POWER_ALERT\",\"CGM_SIGNAL_LOSS\"]"))
        assertTrue(json, json.contains("\"activeAlarms\":[\"LOW_INSULIN_ALARM\"]"))
        assertFalse(json, json.contains(",}"))
    }

    @Test
    fun toJson_emits_charging_state_when_set() {
        val charging = MutableSnapshot().apply {
            batteryPercent = 45
            isCharging = true
        }.toJson()
        assertTrue(charging, charging.contains("\"batteryPercent\":45"))
        assertTrue(charging, charging.contains("\"isCharging\":true"))

        // Unset → omitted (V1 pumps don't report it).
        val noCharge = MutableSnapshot().apply { batteryPercent = 45 }.toJson()
        assertFalse(noCharge, noCharge.contains("isCharging"))
    }

    @Test
    fun toJson_omits_empty_alert_arrays() {
        val json = MutableSnapshot().apply { batteryPercent = 50 }.toJson()
        assertFalse(json, json.contains("activeAlerts"))
        assertFalse(json, json.contains("activeAlarms"))
    }

    @Test
    fun toJson_is_valid_regardless_of_which_field_is_last() {
        // Fields are comma-joined, so the output never has a dangling ",}" no matter
        // which fields are set (the Dart side jsonDecodes this).
        val withoutFirmware = MutableSnapshot().apply {
            batteryPercent = 10
            iobUnits = 0.25
        }.toJson()
        assertFalse(withoutFirmware, withoutFirmware.contains(",}"))
        assertTrue(withoutFirmware, withoutFirmware.endsWith("}"))

        val withFirmware = MutableSnapshot().apply {
            batteryPercent = 10
            firmwareVersion = "1.2.3"
        }.toJson()
        assertFalse(withFirmware, withFirmware.contains(",}"))
    }
}
