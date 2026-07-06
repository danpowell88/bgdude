package com.bgdude.app.pump

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Restarts the pump foreground service after device reboot so the connection re-establishes
 * without the user reopening the app.
 *
 * Two guards (TASK-12):
 *  * On Android 12+ a `connectedDevice` foreground service started from the background
 *    (BOOT_COMPLETED) is rejected outright unless a Bluetooth runtime permission is already
 *    granted — so we check first and skip quietly if it isn't (the app will start the
 *    service after the permission flow next time it's opened).
 *  * The app isn't open to kick off a scan, so we pass [PumpService.EXTRA_AUTO_RECONNECT]
 *    to have the service reconnect itself.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        if (!PumpService.hasBluetoothPermission(context)) {
            Log.i(TAG, "Post-boot pump start skipped: Bluetooth permission not granted")
            return
        }
        val svc = Intent(context, PumpService::class.java)
            .putExtra(PumpService.EXTRA_AUTO_RECONNECT, true)
        context.startForegroundService(svc)
    }

    private companion object {
        const val TAG = "BootReceiver"
    }
}
