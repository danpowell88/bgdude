package com.bgdude.app.pump

import android.content.Context
import androidx.core.content.edit

/**
 * TASK-178: the paired pump's MAC, persisted NATIVELY. The Dart side keeps its own
 * copy for the UI, but a sticky service restart happens with no Dart isolate — the
 * service needs the MAC itself to resume the connection.
 */
object PairedPump {
    private const val PREFS = "bgdude.pump"
    private const val KEY_MAC = "paired_mac"

    fun save(context: Context, mac: String?) {
        if (mac.isNullOrEmpty()) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit { putString(KEY_MAC, mac) }
    }

    fun saved(context: Context): String? = context
        .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        .getString(KEY_MAC, null)

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit { remove(KEY_MAC) }
    }
}
