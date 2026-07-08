package com.bgdude.app.pump

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
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
import com.bgdude.app.CrashLogger
import com.bgdude.app.MainActivity
import com.bgdude.app.widget.WidgetNativePush
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

    // Internal (not private) so a destroy-teardown test can assert the BLE central was
    // actually closed by inspecting the captured handler's own state post-destroy,
    // rather than only inferring it from the absence of a crash (same rationale as
    // PumpCommHandler.bluetoothHandler being internal -- see TASK-263).
    internal var commHandler: PumpCommHandler? = null
        private set

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
        // TASK-187: the service can outlive the activity — make sure the process has
        // the crash handler regardless of which component started first.
        CrashLogger.install(applicationContext)
        createChannel()
        commHandler = PumpCommHandler(applicationContext, this)
        GarminIntegration.init(applicationContext)
        // TASK-177: periodic widget re-render so staleness grey-out is enforced
        // natively, without a live Dart isolate. TASK-236: gated on a widget instance
        // actually existing (BgWidgetProvider.onEnabled/onDisabled own the alarm the
        // rest of the time; this re-arms it reliably across service restarts/reboot).
        WidgetNativePush.scheduleStalenessRendersIfWidgetsExist(applicationContext)
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
            // TASK-12: after a reboot the app isn't open to kick off a scan, so the service
            // reconnects itself when started with the auto-reconnect flag.
            // TASK-178: a NULL intent is the system's sticky restart after a kill —
            // resume the saved pump too, or overnight kills silently end monitoring.
            val savedMac = PairedPump.saved(applicationContext)
            if (ServiceRestartPolicy.shouldResume(
                    nullIntent = intent == null,
                    autoReconnectExtra =
                        intent?.getBooleanExtra(EXTRA_AUTO_RECONNECT, false) == true,
                    hasBluetoothPermission = hasBluetoothPermission(this),
                    hasSavedMac = savedMac != null,
                )
            ) {
                Log.i(TAG, if (intent == null) {
                    "Sticky restart — resuming pump $savedMac"
                } else {
                    "Auto-reconnecting after boot"
                })
                startScan(savedMac)
            }
        } else {
            Log.i(TAG, "BLUETOOTH_CONNECT not granted yet; deferring foreground start")
        }
        return START_STICKY // restart if killed
    }

    /**
     * TASK-202: repeated restart cycles (crash, OS kill, foreground-service
     * revocation) would otherwise accumulate BLE scan state and Connect IQ
     * connections indefinitely — nothing previously stopped `commHandler` or shut
     * down the Garmin SDK when the service itself was torn down. `stop()` was only
     * ever reachable via the command channel, which the OS destroying the service
     * doesn't go through.
     */
    override fun onDestroy() {
        // TASK-262: commHandler.stop() is now internally idempotent, but this is defence in
        // depth — an unpair()/stopScan() double-teardown or an unexpected pumpx2/blessed throw
        // must still let the Garmin shutdown and super.onDestroy() below run.
        // TASK-267: destroy() (not stop()) also marks the handler terminally destroyed, so a
        // concurrent start() racing in from the off-main pairing executor can't orphan a scan.
        try {
            commHandler?.destroy()
        } catch (e: Exception) {
            Log.w(TAG, "commHandler.destroy() threw during onDestroy", e)
        } finally {
            commHandler = null
        }
        try {
            GarminIntegration.shutdown()
        } catch (e: Exception) {
            Log.w(TAG, "GarminIntegration.shutdown() threw during onDestroy", e)
        }
        super.onDestroy()
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
    // TASK-284: unpair() must NOT cancel the staleness alarm -- a widget can still be
    // placed on the home screen with no new data ever coming again, and grey-out is
    // driven ENTIRELY by this periodic re-render (TASK-177). Cancelling it here would
    // freeze the widget at its last live-looking value forever (the exact bug TASK-177
    // fixed, reintroduced for the unpair path specifically). onDisabled (the last
    // widget actually being removed) is the only correct cancellation trigger; unpair
    // leaves it alone regardless of whether a widget still exists.
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
        // TASK-177: keep the home-screen widget honest even if the Flutter engine
        // is dead — push straight from the native snapshot.
        WidgetNativePush.push(applicationContext, snapshot)
        maybeFireUrgentLowBackstop(snapshot.cgmMgdl)
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
            .setContentIntent(mainActivityContentIntent())
            .build()

    /**
     * TASK-203: tapping either the ongoing connection notification or the urgent-low
     * backstop must open the app instead of doing nothing — the backstop in
     * particular exists for exactly the scenario where the Flutter UI is dead, so
     * tapping through to relaunch it is the whole point. `FLAG_IMMUTABLE` is
     * required on API 31+ for a PendingIntent the app itself doesn't need to mutate.
     */
    private fun mainActivityContentIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java)
            .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            this,
            CONTENT_INTENT_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createChannel() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Pump connection",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = "Keeps the t:slim X2 connection alive" },
        )
        // TASK-37: a separate high-importance channel for the native urgent-low backstop.
        nm.createNotificationChannel(
            NotificationChannel(
                URGENT_CHANNEL_ID,
                "Urgent low (safety net)",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Fires when glucose is critically low, even if the app is closed"
            },
        )
    }

    /**
     * TASK-37 AC#2: a dumb, always-on urgent-low safety net running in the native service, so
     * a critical low is still surfaced if the Flutter app (which owns the richer, forecast-
     * based alerts) has been killed to reclaim memory. Fixed [URGENT_LOW_MGDL] threshold with
     * a cooldown so it can't spam. This is additive to the pump/CGM's own alarms.
     */
    private var lastUrgentLowNotifiedMs = 0L

    private fun maybeFireUrgentLowBackstop(cgmMgdl: Int?) {
        val mgdl = cgmMgdl ?: return
        if (mgdl <= 0 || mgdl >= URGENT_LOW_MGDL) return
        val now = System.currentTimeMillis()
        if (now - lastUrgentLowNotifiedMs < URGENT_LOW_COOLDOWN_MS) return
        lastUrgentLowNotifiedMs = now
        if (!hasBluetoothPermission(this)) return // proxy for notifications being usable
        val notif = NotificationCompat.Builder(this, URGENT_CHANNEL_ID)
            .setContentTitle("Urgent low")
            .setContentText("Glucose is $mgdl mg/dL — treat now.")
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(mainActivityContentIntent())
            .build()
        try {
            getSystemService(NotificationManager::class.java)
                .notify(URGENT_NOTIF_ID, notif)
        } catch (e: SecurityException) {
            Log.w(TAG, "Urgent-low notification blocked", e)
        }
    }

    companion object {
        private const val TAG = "PumpService"
        private const val CHANNEL_ID = "pump_connection"
        private const val NOTIF_ID = 42

        // TASK-203: shared request code for the MainActivity content intent — both
        // notifications resolve to the same PendingIntent (same intent + code =
        // FLAG_UPDATE_CURRENT just refreshes it rather than creating duplicates).
        private const val CONTENT_INTENT_REQUEST_CODE = 44

        // TASK-37: native urgent-low safety net.
        private const val URGENT_CHANNEL_ID = "urgent_low_backstop"
        private const val URGENT_NOTIF_ID = 43
        private const val URGENT_LOW_MGDL = 55
        private const val URGENT_LOW_COOLDOWN_MS = 15 * 60 * 1000L

        /** Intent extra: start a scan/reconnect once foregrounded (set by [BootReceiver]). */
        const val EXTRA_AUTO_RECONNECT = "auto_reconnect"

        /** The connectedDevice FGS type requires one of the BT runtime permissions. */
        fun hasBluetoothPermission(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.BLUETOOTH_CONNECT,
                ) == PackageManager.PERMISSION_GRANTED
    }
}
