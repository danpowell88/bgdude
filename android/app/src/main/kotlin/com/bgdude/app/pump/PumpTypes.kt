package com.bgdude.app.pump

/**
 * Plain native-side types for pump state. These are mapped onto the Pigeon-generated
 * classes at the bridge boundary. Kept separate so the comm handler doesn't depend on
 * generated code.
 */

enum class PumpModel { TSLIM_X2, MOBI, UNKNOWN }

enum class PairingCodeType { SHORT_6CHAR, LONG_16CHAR }

enum class ConnectionStage {
    IDLE,
    SCANNING,
    DISCOVERED,
    BONDING,
    AWAITING_PAIRING_CODE,
    JPAKE_IN_PROGRESS,
    AUTHENTICATED,
    CONNECTED,
    DISCONNECTED,
    ERROR,
}

data class NativeConnectionState(
    val stage: ConnectionStage,
    val model: PumpModel,
    val pumpName: String?,
    val macAddress: String?,
    val jpakeProgress: Int?,
    val errorMessage: String?,
)

/** Mutable accumulator updated as pumpx2 responses stream in. */
class MutableSnapshot {
    var timestampEpochMs: Long = 0
    var model: PumpModel = PumpModel.UNKNOWN
    var pumpName: String? = null
    var macAddress: String? = null
    var jpakeProgress: Int? = null

    var batteryPercent: Int? = null
    var isCharging: Boolean? = null
    var reservoirUnits: Double? = null
    var iobUnits: Double? = null
    var basalUnitsPerHour: Double? = null
    var maxBolusUnits: Double? = null
    var maxBasalUnitsPerHour: Double? = null
    var controlIqActive: Boolean? = null

    /** Whether the Control-IQ closed loop is switched on (from ControlIQInfo). */
    var closedLoopEnabled: Boolean? = null

    /** Current Control-IQ user mode: STANDARD, SLEEP or EXERCISE. */
    var controlIqMode: String? = null

    var cgmMgdl: Int? = null
    var cgmTrend: String? = null
    var cgmTimestampEpochMs: Long? = null

    var lastBolusUnits: Double? = null
    var lastBolusTimestampEpochMs: Long? = null

    /**
     * Pump configuration mirror (issue #85): PumpSettings op 83 + PumpGlobals op 87.
     * Read-only — bgdude never writes pump settings (decision-1).
     *
     * lowInsulinThresholdUnits is the pump's OWN low-reservoir warning level, mirrored
     * for the same reason as the CGM thresholds in #90: it explains why the pump warned
     * about insulin when bgdude hadn't yet, or vice versa.
     */
    var autoShutdownEnabled: Boolean? = null
    var autoShutdownHours: Int? = null
    var lowInsulinThresholdUnits: Int? = null
    var cannulaPrimeSizeUnits: Double? = null
    var featureLocked: Boolean? = null
    var quickBolusEnabled: Boolean? = null

    var apiVersion: String? = null
    var firmwareVersion: String? = null
    var activeAlerts: MutableList<String> = mutableListOf()
    var activeAlarms: MutableList<String> = mutableListOf()

    companion object {
        /**
         * TASK-120: wire-format version of this JSON. Evolution policy is
         * ADDITIVE-ONLY: new fields may be appended (old Dart parsers ignore
         * them); renaming, retyping or removing a field requires bumping this
         * AND updating the golden fixture + both contract tests
         * (SnapshotContractTest.kt / contracts_test.dart).
         */
        const val SCHEMA_VERSION = 1
    }

    /** JSON string streamed over the EventChannel (compact, hand-rolled to avoid deps).
     *  Non-null fields are collected and comma-joined so the output is always valid JSON
     *  regardless of which fields are set. */
    fun toJson(): String {
        val parts = mutableListOf<String>()
        fun field(name: String, value: Any?) {
            if (value == null) return
            val v = when (value) {
                is String -> "\"${value.replace("\"", "\\\"")}\""
                else -> value.toString()
            }
            parts.add("\"$name\":$v")
        }
        field("schemaVersion", SCHEMA_VERSION)
        field("timestampEpochMs", System.currentTimeMillis())
        field("model", model.name)
        field("batteryPercent", batteryPercent)
        field("isCharging", isCharging)
        field("reservoirUnits", reservoirUnits)
        field("iobUnits", iobUnits)
        field("basalUnitsPerHour", basalUnitsPerHour)
        field("maxBolusUnits", maxBolusUnits)
        field("maxBasalUnitsPerHour", maxBasalUnitsPerHour)
        field("controlIqActive", controlIqActive)
        field("closedLoopEnabled", closedLoopEnabled)
        field("controlIqMode", controlIqMode)
        field("cgmMgdl", cgmMgdl)
        field("cgmTrend", cgmTrend)
        field("cgmTimestampEpochMs", cgmTimestampEpochMs)
        field("lastBolusUnits", lastBolusUnits)
        field("lastBolusTimestampEpochMs", lastBolusTimestampEpochMs)
        field("autoShutdownEnabled", autoShutdownEnabled)
        field("autoShutdownHours", autoShutdownHours)
        field("lowInsulinThresholdUnits", lowInsulinThresholdUnits)
        field("cannulaPrimeSizeUnits", cannulaPrimeSizeUnits)
        field("featureLocked", featureLocked)
        field("quickBolusEnabled", quickBolusEnabled)
        field("apiVersion", apiVersion)
        field("firmwareVersion", firmwareVersion)
        fun stringArray(name: String, values: List<String>) {
            if (values.isEmpty()) return
            val items = values.joinToString(",") { "\"${it.replace("\"", "\\\"")}\"" }
            parts.add("\"$name\":[$items]")
        }
        stringArray("activeAlerts", activeAlerts)
        stringArray("activeAlarms", activeAlarms)
        return parts.joinToString(",", prefix = "{", postfix = "}")
    }
}
