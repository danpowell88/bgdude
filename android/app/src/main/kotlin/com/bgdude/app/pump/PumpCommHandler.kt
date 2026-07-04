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
import com.jwoglom.pumpx2.pump.messages.builders.CurrentBatteryRequestBuilder
import com.jwoglom.pumpx2.pump.messages.builders.JpakeAuthBuilder
import com.jwoglom.pumpx2.pump.messages.models.KnownDeviceModel
import com.jwoglom.pumpx2.pump.messages.models.PairingCodeType as X2PairingCodeType
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.ControlIQIOBRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.CurrentBasalStatusRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.CurrentEGVGuiDataRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.InsulinStatusRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.LastBolusStatusV2Request
import com.jwoglom.pumpx2.pump.messages.response.authentication.AbstractCentralChallengeResponse
import com.jwoglom.pumpx2.pump.messages.response.authentication.AbstractPumpChallengeResponse
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
    }

    private var bluetoothHandler: TandemBluetoothHandler? = null
    private var peripheral: BluetoothPeripheral? = null
    private var macFilter: String? = null

    /** The challenge from onWaitingForPairingCode, needed to complete pairing. */
    private var pendingChallenge: AbstractCentralChallengeResponse? = null

    /** Accumulates the latest values as responses stream in. */
    val snapshot = MutableSnapshot()

    fun start(macFilter: String?) {
        this.macFilter = macFilter
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
        sendCommand(p, CurrentBasalStatusRequest())
        sendCommand(p, CurrentEGVGuiDataRequest())
        sendCommand(p, LastBolusStatusV2Request())
    }

    fun submitPairingCode(code: String, type: PairingCodeType) {
        val p = peripheral
        val challenge = pendingChallenge
        PumpState.setPairingCode(context, code)
        if (p != null && challenge != null) {
            pair(p, challenge, code)
        }
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
            PumpResponseMapper.apply(message, snapshot)
            listener.onSnapshotUpdated(snapshot)
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to map ${message.javaClass.simpleName}", t)
        }
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

        // If a code is already stored (re-pair after restart), use it directly.
        val saved = PumpState.getPairingCodeCached()
        if (!saved.isNullOrEmpty() && centralChallengeResponse != null) {
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
    }
}
