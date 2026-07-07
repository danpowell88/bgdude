package com.bgdude.app.pump

import android.util.Log

/**
 * TASK-189: pumpx2/BLE callbacks run on library threads — an uncaught throw there
 * kills the whole process (the foreground service dies and glucose monitoring stops).
 * Every externally-invoked callback body in [PumpCommHandler] runs through here:
 * a failure is logged with the callback name and skipped, never fatal.
 */
object SafeCallbacks {
    /**
     * Injectable so JVM unit tests can capture failures (android.util.Log is a
     * throwing stub under plain JVM unit tests). Production leaves the default.
     */
    var logSink: (String, Throwable) -> Unit =
        { msg, t -> Log.e("PumpCommHandler", msg, t) }

    fun run(name: String, block: () -> Unit) {
        try {
            block()
        } catch (t: Throwable) {
            report(name, t)
        }
    }

    fun <T> run(name: String, fallback: T, block: () -> T): T =
        try {
            block()
        } catch (t: Throwable) {
            report(name, t)
            fallback
        }

    private fun report(name: String, t: Throwable) {
        // The guard itself must never throw (AC#2) — not even from the log sink.
        try {
            logSink("callback $name threw (skipped) — service kept alive", t)
        } catch (_: Throwable) {
        }
    }
}
