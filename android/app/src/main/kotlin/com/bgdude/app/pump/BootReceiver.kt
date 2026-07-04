package com.bgdude.app.pump

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restarts the pump foreground service after device reboot so the connection re-establishes
 * without the user reopening the app. Note: Android 15+ restricts which FGS types may be
 * started from BOOT_COMPLETED; `connectedDevice` is permitted when the app has the BLE
 * runtime permissions granted.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            val svc = Intent(context, PumpService::class.java)
            context.startForegroundService(svc)
        }
    }
}
