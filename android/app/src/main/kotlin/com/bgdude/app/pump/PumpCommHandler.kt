package com.bgdude.app.pump

import android.bluetooth.le.ScanResult
import android.content.Context
import android.util.Log
import com.jwoglom.pumpx2.pump.PumpState
import com.jwoglom.pumpx2.pump.TandemError
import com.jwoglom.pumpx2.pump.bluetooth.PumpReadyState
import com.jwoglom.pumpx2.pump.bluetooth.TandemBluetoothHandler
import com.jwoglom.pumpx2.pump.bluetooth.TandemPump
import com.jwoglom.pumpx2.pump.messages.Message
import com.jwoglom.pumpx2.pump.messages.builders.ControlIQInfoRequestBuilder
import com.jwoglom.pumpx2.pump.messages.builders.CurrentBatteryRequestBuilder
import com.jwoglom.pumpx2.pump.messages.builders.JpakeAuthBuilder
import com.jwoglom.pumpx2.pump.messages.models.KnownDeviceModel
import com.jwoglom.pumpx2.pump.messages.models.PairingCodeType as X2PairingCodeType
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.AlarmStatusRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.AlertStatusRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.ControlIQIOBRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.CurrentBasalStatusRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.CurrentEGVGuiDataRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.HistoryLogRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.HistoryLogStatusRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.IDPSegmentRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.IDPSettingsRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.InsulinStatusRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.LastBolusStatusV2Request
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.ProfileStatusRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.PumpVersionRequest
import com.jwoglom.pumpx2.pump.messages.response.authentication.AbstractCentralChallengeResponse
import com.jwoglom.pumpx2.pump.messages.response.authentication.AbstractPumpChallengeResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.HistoryLogStatusResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.IDPSegmentResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.IDPSettingsResponse
import com.jwoglom.pumpx2.pump.messages.response.currentStatus.ProfileStatusResponse
import com.jwoglom.pumpx2.pump.messages.response.historyLog.HistoryLogStreamResponse
import com.jwoglom.pumpx2.pump.messages.response.qualifyingEvent.QualifyingEvent
import com.welie.blessed.BluetoothPeripheral
import com.welie.blessed.HciStatus

/**
 * Owns the pumpx2 [TandemPump] object and the BLE handler. This is the ONLY place that
 * talks to the pump.
 *
 * Read-only by construction: this class sends only `currentStatus` request messages and
 * never calls [enableActionsAffectingInsulinDelivery], so pumpx2 itself blocks any
 * insulin-affecting message. Nothing from `request.control` is imported here — keep it
 * that way; the read-only guarantee is enforced by what is (not) imported and enabled.
 *
 * Modeled on the ControlX2 `PumpCommHandler`, minus every write path.
 */
class PumpCommHandler(
    private val context: Context,
    private val listener: Listener,
) : TandemPump(context) {

    interface Listener {
        fun onState(state: NativeConnectionState)
        fun onSnapshotUpdated(snapshot: MutableSnapshot)
        fun onPairingCodeRequired(type: PairingCodeType)
        fun onCriticalError(message: String)
        /** The decoded active therapy profile (IDP) as JSON, when read from the pump. */
        fun onTherapyProfile(json: String) {}
        /** A raw probe event (sent request / received response) for the Protocol Explorer. */
        fun onProbeMessage(event: Map<String, Any?>) {}
    }

    /**
     * When true, every message sent/received is mirrored to [Listener.onProbeMessage] for the
     * Protocol Explorer. Off by default so the firehose only runs while the screen is open.
     */
    @Volatile
    var probeCapture: Boolean = false

    /**
     * The Protocol Explorer's raw [PROBE_TAG] logcat dump is a developer diagnostic only — it
     * echoes decoded pump payloads, so it's gated to debuggable (debug) builds. Release builds
     * never write it (the in-app Log tab still works via [Listener.onProbeMessage]).
     */
    private val probeLogging: Boolean =
        (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0

    /** Buffer of decoded history-log entries; drained by the Dart backfill service. */
    private val historyBuffer = ArrayDeque<Map<String, Any?>>()
    private val profileMapper = PumpProfileMapper()

    private var bluetoothHandler: TandemBluetoothHandler? = null
    private var peripheral: BluetoothPeripheral? = null
    private var macFilter: String? = null

    /** The challenge from onWaitingForPairingCode, needed to complete pairing. */
    private var pendingChallenge: AbstractCentralChallengeResponse? = null

    /** Accumulates the latest values as responses stream in. */
    val snapshot = MutableSnapshot()

    fun start(macFilter: String?) {
        this.macFilter = macFilter
        // Select the pairing scheme up front. On a fresh pair pumpx2 otherwise falls back
        // to the 16-character challenge-response default (because ApiVersionResponse hasn't
        // arrived yet), which newer JPAKE firmware never answers — so pairing silently
        // stalls. Default to JPAKE (6-digit) unless we already hold a derived secret from a
        // prior JPAKE pairing (re-auth uses that). This affects only the auth handshake,
        // not the read-only guarantee.
        if (PumpState.getJpakeDerivedSecretCached().isNullOrEmpty()) {
            PumpState.pairingCodeType = X2PairingCodeType.SHORT_6CHAR
        }
        val handler = TandemBluetoothHandler.getInstance(context, this)
        bluetoothHandler = handler
        emitState(ConnectionStage.SCANNING)
        handler.startScan()
    }

    fun stop() {
        bluetoothHandler?.stop()
        emitState(ConnectionStage.IDLE)
    }

    fun requestFullStatus() {
        val p = peripheral ?: return
        // Fire the read-only status requests; responses arrive in onReceiveMessage.
        // Battery needs the version-matched request; the rest are unversioned.
        PumpState.getPumpAPIVersion()?.let { api ->
            sendCommand(p, CurrentBatteryRequestBuilder.create(api))
        }
        sendCommand(p, InsulinStatusRequest())
        sendCommand(p, ControlIQIOBRequest())
        // Control-IQ info (closed-loop on/off + user mode) is version-matched like battery.
        PumpState.getPumpAPIVersion()?.let { api ->
            sendCommand(p, ControlIQInfoRequestBuilder.create(api))
        }
        sendCommand(p, CurrentBasalStatusRequest())
        sendCommand(p, CurrentEGVGuiDataRequest())
        sendCommand(p, LastBolusStatusV2Request())
        // Active alerts/alarms (for the user's awareness) + firmware version.
        sendCommand(p, AlertStatusRequest())
        sendCommand(p, AlarmStatusRequest())
        sendCommand(p, PumpVersionRequest())
    }

    /**
     * Fire a single read-only `currentStatus` request by class name (Protocol Explorer).
     * Returns null on success, or a human-readable refusal/queue reason. The request is
     * safety-gated by [ProtocolProbe.buildSafeRequest]; nothing insulin-affecting can be sent.
     */
    fun sendProbe(name: String, arg1: Int?, arg2: Int?): String? {
        val p = peripheral ?: return "not connected"
        return when (val r = ProtocolProbe.buildSafeRequest(name, arg1, arg2)) {
            is ProtocolProbe.Result.Refused -> "refused: ${r.reason}"
            is ProtocolProbe.Result.Ok -> {
                if (probeCapture) {
                    if (probeLogging) Log.i(PROBE_TAG, "tx ${r.message.javaClass.simpleName}")
                    listener.onProbeMessage(
                        ProtocolProbe.describe(r.message, "tx", System.currentTimeMillis()),
                    )
                }
                sendCommand(p, r.message)
                null
            }
        }
    }

    /** Read the active Insulin Delivery Profile (basal/ISF/CR/targets). */
    fun requestProfile() {
        peripheral?.let { sendCommand(it, ProfileStatusRequest()) }
    }

    /** Ask the pump for the most recent [count] history-log entries. */
    fun requestRecentHistory(count: Int = 500) {
        peripheral?.let { sendCommand(it, HistoryLogStatusRequest()) }
        // The status response arrives async; on it we issue the ranged HistoryLogRequest.
        pendingHistoryCount = count
    }

    /** Drain and return the accumulated history-log entries (for the Dart importer). */
    @Synchronized
    fun drainHistory(): List<Map<String, Any?>> {
        val out = historyBuffer.toList()
        historyBuffer.clear()
        return out
    }

    private var pendingHistoryCount = 0

    fun submitPairingCode(code: String, type: PairingCodeType) {
        val p = peripheral ?: return
        PumpState.setPairingCode(context, code)
        // JPAKE (6-digit) pumps supply no CentralChallenge, so pendingChallenge is null —
        // pair() must still be called to drive the JPAKE handshake. Only the legacy 16-char
        // challenge-response path carries a non-null challenge. Gating on challenge != null
        // (the old behaviour) meant JPAKE pumps could never finish pairing.
        Log.i(TAG, "submitPairingCode: type=$type challenge=" +
            if (pendingChallenge == null) "null(JPAKE)" else "present")
        pair(p, pendingChallenge, code)
    }

    fun unpair() {
        bluetoothHandler?.stop()
        PumpState.resetState(context)
        pendingChallenge = null
        peripheral = null
        emitState(ConnectionStage.IDLE)
    }

    // --- pumpx2 TandemPump callbacks (read-only subset) ---

    override fun onReceiveMessage(peripheral: BluetoothPeripheral, message: Message) {
        try {
            if (probeCapture) {
                val event = ProtocolProbe.describe(message, "rx", System.currentTimeMillis())
                if (probeLogging) {
                    Log.i(PROBE_TAG, "rx ${event["name"]} op=${event["opcode"]} " +
                        "cargo=[${event["cargoHex"]}] json=${event["json"]}")
                }
                listener.onProbeMessage(event)
            }
            PumpResponseMapper.apply(message, snapshot)
            listener.onSnapshotUpdated(snapshot)
            handleProfileMessage(peripheral, message)
            handleHistoryMessage(peripheral, message)
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to map ${message.javaClass.simpleName}", t)
        }
    }

    /** Drive the IDP read: settings → per-segment requests → emit the profile. */
    private fun handleProfileMessage(peripheral: BluetoothPeripheral, message: Message) {
        when (message) {
            is ProfileStatusResponse ->
                sendCommand(peripheral, IDPSettingsRequest(message.activeIdpSlotId))
            is IDPSettingsResponse -> {
                val idpId = profileMapper.onSettings(message)
                for (i in 0 until message.numberOfProfileSegments) {
                    sendCommand(peripheral, IDPSegmentRequest(idpId, i))
                }
            }
            is IDPSegmentResponse -> {
                profileMapper.onSegment(message)
                if (profileMapper.complete) listener.onTherapyProfile(profileMapper.toJson())
            }
            else -> {}
        }
    }

    private fun handleHistoryMessage(peripheral: BluetoothPeripheral, message: Message) {
        if (message is HistoryLogStatusResponse) {
            val count = pendingHistoryCount
            if (count > 0) {
                val start = (message.lastSequenceNum - count + 1)
                    .coerceAtLeast(message.firstSequenceNum)
                sendCommand(peripheral, HistoryLogRequest(start, count))
                pendingHistoryCount = 0
            }
            return
        }
        // History entries arrive inside a HistoryLogStreamResponse (a Message) — unpack the
        // decoded HistoryLog list and map each. The entries are not Messages themselves, so
        // mapping the outer Message directly never matched anything.
        if (message !is HistoryLogStreamResponse) return
        val entries = message.historyLogs.mapNotNull { PumpHistoryMapper.map(it) }
        if (entries.isEmpty()) return
        synchronized(this) { historyBuffer.addAll(entries) }
    }

    override fun onReceiveQualifyingEvent(
        peripheral: BluetoothPeripheral,
        events: Set<QualifyingEvent>,
    ) {
        // A qualifying event (e.g. new CGM reading, bolus completed) — pull fresh status.
        requestFullStatus()
    }

    override fun onWaitingForPairingCode(
        peripheral: BluetoothPeripheral,
        centralChallengeResponse: AbstractCentralChallengeResponse?,
    ) {
        this.peripheral = peripheral
        this.pendingChallenge = centralChallengeResponse

        // If a code is already stored (re-pair after restart), use it directly. Works for
        // JPAKE too, where centralChallengeResponse is null.
        val saved = PumpState.getPairingCodeCached()
        if (!saved.isNullOrEmpty()) {
            pair(peripheral, centralChallengeResponse, saved)
            return
        }

        val type = if (PumpState.pairingCodeType == X2PairingCodeType.LONG_16CHAR) {
            PairingCodeType.LONG_16CHAR
        } else {
            PairingCodeType.SHORT_6CHAR
        }
        emitState(ConnectionStage.AWAITING_PAIRING_CODE)
        listener.onPairingCodeRequired(type)
    }

    override fun onInitialPumpConnection(peripheral: BluetoothPeripheral) {
        this.peripheral = peripheral
        emitState(ConnectionStage.BONDING)
        super.onInitialPumpConnection(peripheral)
    }

    override fun onPumpConnected(peripheral: BluetoothPeripheral) {
        this.peripheral = peripheral
        emitState(ConnectionStage.CONNECTED)
        // Base class auto-sends ApiVersion/PumpVersion/TimeSinceReset; then get status.
        super.onPumpConnected(peripheral)
        requestFullStatus()
        // Read the therapy profile and backfill recent history on connect.
        requestProfile()
        requestRecentHistory()
    }

    override fun onPumpDiscovered(
        peripheral: BluetoothPeripheral,
        scanResult: ScanResult?,
        readyState: PumpReadyState,
    ): Boolean {
        val mac = macFilter
        if (mac != null && !peripheral.address.equals(mac, ignoreCase = true)) {
            return false // ignore other pumps
        }
        snapshot.pumpName = peripheral.name
        snapshot.macAddress = peripheral.address
        emitState(ConnectionStage.DISCOVERED)
        return true
    }

    override fun onPumpModel(peripheral: BluetoothPeripheral, model: KnownDeviceModel) {
        snapshot.model = when (model) {
            KnownDeviceModel.TSLIM_X2 -> PumpModel.TSLIM_X2
            KnownDeviceModel.MOBI -> PumpModel.MOBI
            else -> PumpModel.UNKNOWN
        }
        listener.onSnapshotUpdated(snapshot)
    }

    override fun onJpakeProgress(step: JpakeAuthBuilder.JpakeStep) {
        snapshot.jpakeProgress = step.ordinal
        emitState(ConnectionStage.JPAKE_IN_PROGRESS)
    }

    override fun onInvalidPairingCode(
        peripheral: BluetoothPeripheral,
        response: AbstractPumpChallengeResponse?,
    ) {
        pendingChallenge = null
        emitState(ConnectionStage.ERROR, "Invalid pairing code")
    }

    override fun onPumpDisconnected(
        peripheral: BluetoothPeripheral,
        status: HciStatus,
    ): Boolean {
        emitState(ConnectionStage.DISCONNECTED)
        // Return true to request an automatic reconnect (proof-of-concept pairing can
        // drop; the service surfaces persistent failures to the UI).
        return true
    }

    override fun onPumpCriticalError(peripheral: BluetoothPeripheral, error: TandemError) {
        listener.onCriticalError(error.name)
        emitState(ConnectionStage.ERROR, error.name)
    }

    private fun emitState(stage: ConnectionStage, error: String? = null) {
        listener.onState(
            NativeConnectionState(
                stage = stage,
                model = snapshot.model,
                pumpName = snapshot.pumpName,
                macAddress = snapshot.macAddress,
                jpakeProgress = snapshot.jpakeProgress,
                errorMessage = error,
            )
        )
    }

    companion object {
        private const val TAG = "PumpCommHandler"
        /** Distinct tag so the Protocol Explorer firehose is easy to `adb logcat -s`. */
        const val PROBE_TAG = "PumpProbe"
    }
}
