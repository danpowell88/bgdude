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
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.BasalLimitSettingsRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.GlobalMaxBolusSettingsRequest
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

    /**
     * TASK-267: `start()` runs on [PumpHostApiImpl]'s off-main pairing executor (TASK-205)
     * while `stop()`/`onDestroy` run on the main thread — [bluetoothHandler] is guarded by
     * [bluetoothLock] everywhere it's read or written so the two can't race (see
     * [stopBluetooth] and [destroy]).
     */
    private val bluetoothLock = Any()

    // Internal (not private) so a start-destroy race test can assert the post-race
    // invariant directly instead of only inferring it from absence of a crash.
    @Volatile
    internal var bluetoothHandler: TandemBluetoothHandler? = null
        private set

    @Volatile
    private var macFilter: String? = null

    /** Set once by [destroy]; makes every later [start] a no-op rather than orphaning a
     *  scan on a handler this service has already torn down for good. */
    @Volatile
    internal var destroyed = false
        private set

    private var peripheral: BluetoothPeripheral? = null

    /** The challenge from onWaitingForPairingCode, needed to complete pairing. */
    private var pendingChallenge: AbstractCentralChallengeResponse? = null

    /** Accumulates the latest values as responses stream in. Mutated only on the BLE
     *  callback thread, but read from the platform thread via [snapshotJson], so all writes
     *  and that read are guarded by [snapshotLock] to hand out a consistent snapshot
     *  (TASK-43). */
    val snapshot = MutableSnapshot()
    private val snapshotLock = Any()

    /** A consistent JSON copy of the current snapshot (safe to call off the BLE thread). */
    fun snapshotJson(): String = synchronized(snapshotLock) { snapshot.toJson() }

    fun start(macFilter: String?) = synchronized(bluetoothLock) {
        // TASK-267: start() runs on a background executor and can race a concurrent
        // destroy() (e.g. the service being torn down right as a re-pair request comes
        // in) -- once destroyed, never start a scan nobody will ever stop again.
        if (destroyed) {
            Log.w(TAG, "start(): ignored -- handler already destroyed")
            return@synchronized
        }
        this.macFilter = macFilter
        // Select the pairing scheme up front. On a fresh pair pumpx2 otherwise falls back
        // to the 16-character challenge-response default (because ApiVersionResponse hasn't
        // arrived yet), which newer JPAKE firmware never answers — so pairing silently
        // stalls. Default to JPAKE (6-digit) unless we already hold a derived secret from a
        // prior JPAKE pairing (re-auth uses that). This affects only the auth handshake,
        // not the read-only guarantee.
        PairingDecision.initialScheme(PumpState.getJpakeDerivedSecretCached())
            ?.let { PumpState.pairingCodeType = it }
        val handler = TandemBluetoothHandler.getInstance(context, this)
        bluetoothHandler = handler
        emitState(ConnectionStage.SCANNING)
        handler.startScan()
    }

    fun stop() {
        stopBluetooth()
        emitState(ConnectionStage.IDLE)
    }

    /**
     * Terminal teardown for [PumpService.onDestroy]: stops the same as [stop] but also
     * marks this handler destroyed so a [start] that was already in flight on the
     * pairing executor (TASK-267) cannot slip in afterwards and orphan a scan that
     * nothing will ever stop -- whichever of destroy()/start() acquires [bluetoothLock]
     * second sees the other's effect (either the just-started handler gets stopped, or
     * the flag makes the start a no-op before it ever calls `startScan()`).
     */
    fun destroy() {
        synchronized(bluetoothLock) { destroyed = true }
        stop()
    }

    /**
     * TASK-262: `TandemBluetoothHandler` is a process-wide singleton (`getInstance`), and its
     * `stop()` → blessed's `BluetoothCentralManager.close()` unregisters a broadcast receiver
     * that is registered only once, in the handler's constructor — a second `close()` (e.g.
     * `unpair()` followed by the service's own `onDestroy`) throws `IllegalArgumentException:
     * Receiver not registered`. Nulling [bluetoothHandler] up front makes every path here
     * idempotent (a second call is a no-op), and `resetInstance()` drops the singleton so a
     * later `start()` (a sticky-restart reconnect) builds a fresh handler instead of reusing
     * one whose receiver is already unregistered and whose callbacks route to a dead listener.
     */
    private fun stopBluetooth() {
        val handler = synchronized(bluetoothLock) {
            val h = bluetoothHandler
            bluetoothHandler = null
            h
        } ?: return
        try {
            handler.stop()
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "stop(): BLE handler was already torn down", e)
        }
        TandemBluetoothHandler.resetInstance()
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
        // TASK-72: the pump's configured max bolus + basal limits (read-only).
        sendCommand(p, GlobalMaxBolusSettingsRequest())
        sendCommand(p, BasalLimitSettingsRequest())
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
        val request = PairingDecision.pairRequest(pendingChallenge, code)
        Log.i(TAG, "submitPairingCode: type=$type challenge=" +
            if (request.challenge == null) "null(JPAKE)" else "present")
        if (request.invokePair) pair(p, request.challenge, request.code)
    }

    fun unpair() {
        stopBluetooth()
        PumpState.resetState(context)
        PairedPump.clear(context) // TASK-178: no auto-resume after an unpair
        pendingChallenge = null
        peripheral = null
        emitState(ConnectionStage.IDLE)
    }

    // --- pumpx2 TandemPump callbacks (read-only subset) ---

    /**
     * TASK-189: every externally-invoked callback body goes through [SafeCallbacks]:
     * a failure is logged with the callback name and skipped, never fatal.
     */
    private fun safe(name: String, block: () -> Unit) = SafeCallbacks.run(name, block)

    private fun <T> safe(name: String, fallback: T, block: () -> T): T =
        SafeCallbacks.run(name, fallback, block)

    override fun onReceiveMessage(peripheral: BluetoothPeripheral, message: Message) =
        safe("onReceiveMessage(${message.javaClass.simpleName})") {
            if (probeCapture) {
                val event = ProtocolProbe.describe(message, "rx", System.currentTimeMillis())
                if (probeLogging) {
                    Log.i(PROBE_TAG, "rx ${event["name"]} op=${event["opcode"]} " +
                        "cargo=[${event["cargoHex"]}] json=${event["json"]}")
                }
                listener.onProbeMessage(event)
            }
            synchronized(snapshotLock) { PumpResponseMapper.apply(message, snapshot) }
            listener.onSnapshotUpdated(snapshot)
            handleProfileMessage(peripheral, message)
            handleHistoryMessage(peripheral, message)
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
            val range = HistoryRangePlanner.plan(
                message.firstSequenceNum, message.lastSequenceNum, pendingHistoryCount,
            )
            if (range != null) {
                sendCommand(peripheral, HistoryLogRequest(range.start, range.count))
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
    ) = safe("onReceiveQualifyingEvent") {
        // A qualifying event (e.g. new CGM reading, bolus completed) — pull fresh status.
        requestFullStatus()
    }

    override fun onWaitingForPairingCode(
        peripheral: BluetoothPeripheral,
        centralChallengeResponse: AbstractCentralChallengeResponse?,
    ) = safe("onWaitingForPairingCode") {
        this.peripheral = peripheral
        this.pendingChallenge = centralChallengeResponse

        // If a code is already stored (re-pair after restart), use it directly. Works for
        // JPAKE too, where centralChallengeResponse is null.
        val saved = PumpState.getPairingCodeCached()
        if (!saved.isNullOrEmpty()) {
            pair(peripheral, centralChallengeResponse, saved)
            return@safe
        }

        val type = PairingDecision.promptType(PumpState.pairingCodeType)
        emitState(ConnectionStage.AWAITING_PAIRING_CODE)
        listener.onPairingCodeRequired(type)
    }

    override fun onInitialPumpConnection(peripheral: BluetoothPeripheral) =
        safe("onInitialPumpConnection") {
            this.peripheral = peripheral
            emitState(ConnectionStage.BONDING)
            super.onInitialPumpConnection(peripheral)
        }

    override fun onPumpConnected(peripheral: BluetoothPeripheral) =
        safe("onPumpConnected") {
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
        // Fallback true: on an unexpected throw, still attempt the connection —
        // failing open keeps monitoring alive; failing closed would ignore the pump.
    ): Boolean = safe("onPumpDiscovered", fallback = true) {
        val mac = macFilter
        if (mac != null && !peripheral.address.equals(mac, ignoreCase = true)) {
            return@safe false // ignore other pumps
        }
        synchronized(snapshotLock) {
            snapshot.pumpName = peripheral.name
            snapshot.macAddress = peripheral.address
        }
        // TASK-178: persist the MAC natively so a sticky service restart (no Dart
        // isolate alive) can resume the connection on its own.
        PairedPump.save(context, peripheral.address)
        emitState(ConnectionStage.DISCOVERED)
        true
    }

    override fun onPumpModel(peripheral: BluetoothPeripheral, model: KnownDeviceModel) =
        safe("onPumpModel") {
            synchronized(snapshotLock) {
                snapshot.model = when (model) {
                    KnownDeviceModel.TSLIM_X2 -> PumpModel.TSLIM_X2
                    KnownDeviceModel.MOBI -> PumpModel.MOBI
                    else -> PumpModel.UNKNOWN
                }
            }
            listener.onSnapshotUpdated(snapshot)
        }

    override fun onJpakeProgress(step: JpakeAuthBuilder.JpakeStep) =
        safe("onJpakeProgress") {
            synchronized(snapshotLock) { snapshot.jpakeProgress = step.ordinal }
            emitState(ConnectionStage.JPAKE_IN_PROGRESS)
        }

    override fun onInvalidPairingCode(
        peripheral: BluetoothPeripheral,
        response: AbstractPumpChallengeResponse?,
    ) = safe("onInvalidPairingCode") {
        pendingChallenge = null
        emitState(ConnectionStage.ERROR, "Invalid pairing code")
    }

    override fun onPumpDisconnected(
        peripheral: BluetoothPeripheral,
        status: HciStatus,
        // Fallback true: always keep requesting the automatic reconnect.
    ): Boolean = safe("onPumpDisconnected", fallback = true) {
        emitState(ConnectionStage.DISCONNECTED)
        // Return true to request an automatic reconnect (proof-of-concept pairing can
        // drop; the service surfaces persistent failures to the UI).
        true
    }

    // AC#2 (TASK-189): the critical-error path itself must never throw.
    override fun onPumpCriticalError(peripheral: BluetoothPeripheral, error: TandemError) =
        safe("onPumpCriticalError") {
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
