package com.bgdude.app

import android.content.Context
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * TASK-187: process-wide default uncaught-exception handler. A fatal native/JVM crash
 * (e.g. in the pump service's BLE stack) previously died without a trace; this persists
 * the timestamp, thread and stack to app-local storage BEFORE the process dies, into the
 * same `filesDir/last_crash.txt` the Dart side writes, so the Developer log screen shows
 * it on next launch. Chains to the previous handler so the normal crash flow still runs.
 */
object CrashLogger {
    private const val FILE_NAME = "last_crash.txt"
    private const val MAX_BYTES = 64_000L

    @Volatile
    private var installed = false

    fun install(context: Context) {
        if (installed) return
        installed = true
        val filesDir = context.applicationContext.filesDir
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val file = File(filesDir, FILE_NAME)
                // Keep the newest crash: drop old content past the cap.
                if (file.length() > MAX_BYTES) file.delete()
                val stamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
                    .format(Date())
                file.appendText(
                    "=== $stamp native uncaught on thread=${thread.name}\n" +
                        Log.getStackTraceString(throwable) + "\n"
                )
            } catch (_: Throwable) {
                // Last-resort sink: never mask the original crash.
            }
            previous?.uncaughtException(thread, throwable)
        }
    }
}
