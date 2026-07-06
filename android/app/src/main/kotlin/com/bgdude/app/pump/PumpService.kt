package com.bgdude.app.pump

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Binder
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.bgdude.app.garmin.GarminIntegration

/**
 * Foreground service (type `connectedDevice`) that owns the pump connection for the
 * lifetime of the app process, independent of whether the Flutter UI is foregrounded or
 * swiped away. This is the robustness anchor: the BLE link and pumpx2 callbacks live
 * here, so UI death doesn't drop the pump.
 *
 * The service is bound by [PumpBridge] (for command relay) and also started as a
 * foreground service so Android keeps it alive.
 */
class PumpService : Service(), PumpCommHandler.Listener {

    private val binder = LocalBinder()
    private var commHandler: PumpCommHandler? = null

    /** Callbacks the bridge registers to receive state/snapshot/pairing events. */
    var callbacks: Callbacks? = null

    interface Callbacks {
        fun onState(state: NativeConnectionState)
        fun onSnapshot(json: String)
        fun onPairingCodeRequired(type: PairingCodeType)
        fun onCriticalError(message: String)
        fun onTherapyProfile(json: String)
        fun onProbeMessage(event: Map<String, Any?>)
    }

    inner class LocalBinder : Binder() {
        fun service(): PumpService = this@PumpService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        createChannel()
        commHandler = PumpCommHandler(applicationContext, this)
        GarminIntegration.init(applicationContext)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Android 14+ refuses a connectedDevice FGS unless a Bluetooth runtime
        // permission is already granted — on a fresh install it won't be. Never
        // crash: run un-foregrounded (bound-only) until the app retries after the
        // permission flow (see hasBluetoothPermission + PumpBridge).
        if (hasBluetoothPermission(this)) {
            try {
                startForegroundCompat()
            } catch (e: SecurityException) {
                Log.w(TAG, "FGS start rejected; continuing bound-only", e)
            }
        } else {
            Log.i(TAG, "BLUETOOTH_CONNECT not granted yet; deferring foreground start")
        }
        return START_STICKY // restart if killed
    }

    fun startScan(macFilter: String?) = commHandler?.start(macFilter)
    fun stopScan() = commHandler?.stop()
    fun requestStatus() = commHandler?.requestFullStatus()
    fun requestProfile() = commHandler?.requestProfile()
    fun fetchHistory(): List<Map<String, Any?>> = commHandler?.drainHistory() ?: emptyList()
    fun sendProbe(name: String, arg1: Int?, arg2: Int?): String? =
        commHandler?.sendProbe(name, arg1, arg2) ?: "not connected"
    fun setProbeCapture(enabled: Boolean) {
        commHandler?.probeCapture = enabled
    }
    fun submitPairingCode(code: String, type: PairingCodeType) =
        commHandler?.submitPairingCode(code, type)
    fun unpair() = commHandler?.unpair()
    fun snapshotJson(): String = commHandler?.snapshotJson() ?: "{}"

    // --- PumpCommHandler.Listener → forward to bridge + refresh notification ---

    override fun onState(state: NativeConnectionState) {
        updateNotification(state)
        callbacks?.onState(state)
    }

    override fun onSnapshotUpdated(snapshot: MutableSnapshot) {
        val json = snapshot.toJson()
        callbacks?.onSnapshot(json)
        GarminIntegration.onSnapshot(json)
    }

    override fun onPairingCodeRequired(type: PairingCodeType) {
        callbacks?.onPairingCodeRequired(type)
    }

    override fun onCriticalError(message: String) {
        callbacks?.onCriticalError(message)
    }

    override fun onTherapyProfile(json: String) {
        callbacks?.onTherapyProfile(json)
    }

    override fun onProbeMessage(event: Map<String, Any?>) {
        callbacks?.onProbeMessage(event)
    }

    private fun startForegroundCompat() {
        val notification = buildNotification("Starting pump connection…")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIF_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    private fun updateNotification(state: NativeConnectionState) {
        val text = when (state.stage) {
            ConnectionStage.CONNECTED -> "Connected to ${state.pumpName ?: "pump"}"
            ConnectionStage.SCANNING -> "Searching for pump…"
            ConnectionStage.AWAITING_PAIRING_CODE -> "Enter pairing code from pump"
            ConnectionStage.DISCONNECTED -> "Pump disconnected — reconnecting…"
            ConnectionStage.ERROR -> state.errorMessage ?: "Pump error"
            else -> "Pump: ${state.stage.name.lowercase()}"
        }
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIF_ID, buildNotification(text))
    }

    private fun buildNotification(text: String): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("bgdude")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Pump connection",
            NotificationManager.IMPORTANCE_LOW,
        ).apply { description = "Keeps the t:slim X2 connection alive" }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        private const val TAG = "PumpService"
        private const val CHANNEL_ID = "pump_connection"
        private const val NOTIF_ID = 42

        /** The connectedDevice FGS type requires one of the BT runtime permissions. */
        fun hasBluetoothPermission(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.BLUETOOTH_CONNECT,
                ) == PackageManager.PERMISSION_GRANTED
    }
}
