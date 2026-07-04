package com.bgdude.app.pump

import android.content.Context
import android.util.Log
import com.jwoglom.pumpx2.pump.PumpState
import com.jwoglom.pumpx2.pump.bluetooth.TandemBluetoothHandler
import com.jwoglom.pumpx2.pump.bluetooth.TandemPump
import com.jwoglom.pumpx2.pump.messages.Message
import com.jwoglom.pumpx2.pump.messages.builders.CurrentBatteryRequestBuilder
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.ApiVersionRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.ControlIQIOBRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.CurrentBasalStatusRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.CurrentEGVGuiDataRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.InsulinStatusRequest
import com.jwoglom.pumpx2.pump.messages.request.currentStatus.LastBolusStatusV2Request
import com.welie.blessed.BluetoothPeripheral

/**
 * Owns the pumpx2 [TandemPump] object and the BLE handler. This is the ONLY place that
 * talks to the pump.
 *
 * Read-only by construction: this class imports and sends only request classes from the
 * `request.currentStatus` package. It deliberately does not import anything from
 * `request.control` (InitiateBolusRequest, SetTempRateRequest, FactoryResetRequest, …),
 * so there is no code path that can modify insulin delivery. Keep it that way — the
 * read-only guarantee is enforced by what is (not) imported here.
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
        bluetoothHandler?.stopScan()
        peripheral?.let { bluetoothHandler?.disconnect(it) }
        emitState(ConnectionStage.IDLE)
    }

    fun requestFullStatus() {
        val p = peripheral ?: return
        // Fire the read-only status requests; responses arrive in onReceiveMessage.
        sendCommand(p, CurrentBatteryRequestBuilder.create(PumpState.tandemPumpApiVersion))
        sendCommand(p, InsulinStatusRequest())
        sendCommand(p, ControlIQIOBRequest())
        sendCommand(p, CurrentBasalStatusRequest())
        sendCommand(p, CurrentEGVGuiDataRequest())
        sendCommand(p, LastBolusStatusV2Request())
    }

    fun submitPairingCode(code: String, type: PairingCodeType) {
        // PumpState stores the code; the handshake resumes on the next connection attempt.
        PumpState.setPairingCode(code)
        peripheral?.let { bluetoothHandler?.connect(it) }
    }

    fun unpair() {
        PumpState.clearPairingCode()
        peripheral?.let { bluetoothHandler?.removeBond(it) }
        emitState(ConnectionStage.IDLE)
    }

    // --- pumpx2 TandemPump callbacks (read-only subset) ---

    override fun onReceiveMessage(peripheral: BluetoothPeripheral, message: Message?) {
        if (message == null) return
        try {
            PumpResponseMapper.apply(message, snapshot)
            listener.onSnapshotUpdated(snapshot)
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to map ${message.javaClass.simpleName}", t)
        }
    }

    override fun onReceiveQualifyingEvent(
        peripheral: BluetoothPeripheral,
        events: MutableSet<com.jwoglom.pumpx2.pump.messages.models.PumpQualifyingEvent>?,
    ) {
        // A qualifying event (e.g. new CGM reading, bolus completed) — pull fresh status.
        requestFullStatus()
    }

    override fun onWaitingForPairingCode(peripheral: BluetoothPeripheral, pumpApiMessage: Message?) {
        this.peripheral = peripheral
        val type = if (PumpState.getPairingCodeType() == PumpState.PairingCodeType.LONG_16CHAR) {
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

    override fun onPumpDiscovered(peripheral: BluetoothPeripheral, scanResult: android.bluetooth.le.ScanResult?): Boolean {
        val mac = macFilter
        if (mac != null && !peripheral.address.equals(mac, ignoreCase = true)) {
            return false // ignore other pumps
        }
        snapshot.pumpName = peripheral.name
        snapshot.macAddress = peripheral.address
        emitState(ConnectionStage.DISCOVERED)
        return true
    }

    override fun onPumpModel(peripheral: BluetoothPeripheral, model: com.jwoglom.pumpx2.pump.messages.models.KnownDeviceModel?) {
        snapshot.model = when (model?.name) {
            "TSLIM_X2" -> PumpModel.TSLIM_X2
            "MOBI" -> PumpModel.MOBI
            else -> PumpModel.UNKNOWN
        }
        listener.onSnapshotUpdated(snapshot)
    }

    override fun onJpakeProgress(peripheral: BluetoothPeripheral, step: Int) {
        snapshot.jpakeProgress = step
        emitState(ConnectionStage.JPAKE_IN_PROGRESS)
    }

    override fun onInvalidPairingCode(peripheral: BluetoothPeripheral, message: Message?) {
        emitState(ConnectionStage.ERROR, "Invalid pairing code")
    }

    override fun onPumpDisconnected(peripheral: BluetoothPeripheral, status: Int): Boolean {
        emitState(ConnectionStage.DISCONNECTED)
        // Return true to request an automatic reconnect (proof-of-concept pairing can
        // drop; the service surfaces persistent failures to the UI).
        return true
    }

    override fun onPumpCriticalError(peripheral: BluetoothPeripheral, reason: String?) {
        listener.onCriticalError(reason ?: "Unknown pump error")
        emitState(ConnectionStage.ERROR, reason)
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
