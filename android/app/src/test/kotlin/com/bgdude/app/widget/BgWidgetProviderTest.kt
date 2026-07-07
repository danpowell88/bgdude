package com.bgdude.app.widget

import android.app.Application
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import com.bgdude.app.R
import com.bgdude.app.pump.SafeCallbacks
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * TASK-196: BgWidgetProvider has no `android:process` isolation, so it shares
 * PumpService's process — an uncaught exception escaping onReceive would kill the
 * BLE link and the native urgent-low backstop along with the widget. This asserts
 * the documented throw vector (a wrong-typed value under a prefs key that
 * `SharedPreferences.getString` reads) can never escape.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class BgWidgetProviderTest {

    private val app get() = ApplicationProvider.getApplicationContext<Application>()
    private val logged = mutableListOf<Pair<String, Throwable>>()

    @Before
    fun captureLog() {
        SafeCallbacks.logSink = { msg, t -> logged.add(msg to t) }
    }

    @After
    fun resetLog() {
        SafeCallbacks.logSink = { _, _ -> }
    }

    private fun installWidget(): Int =
        shadowOf(AppWidgetManager.getInstance(app))
            .createWidget(BgWidgetProvider::class.java, R.layout.bg_widget)

    @Test
    fun `a wrong-typed value under BG_TEXT does not escape onReceive`() {
        installWidget()
        val prefs =
            app.getSharedPreferences(WidgetNativePush.PREFS_NAME, Context.MODE_PRIVATE)
        // SharedPreferences.getString throws ClassCastException when a non-String
        // was stored under the key it reads — exactly the documented throw vector.
        prefs.edit().putInt(WidgetKeys.BG_TEXT, 12345).commit()

        // Must not throw.
        BgWidgetProvider().onReceive(app, Intent(WidgetNativePush.ACTION_REFRESH))

        assertTrue(logged.any { it.first.contains("BgWidgetProvider.render") })
    }

    @Test
    fun `a wrong-typed value under TREND also does not escape onReceive`() {
        installWidget()
        val prefs =
            app.getSharedPreferences(WidgetNativePush.PREFS_NAME, Context.MODE_PRIVATE)
        // A different getString-read key, for breadth beyond BG_TEXT specifically.
        prefs.edit().putBoolean(WidgetKeys.TREND, true).commit()

        BgWidgetProvider().onReceive(app, Intent(WidgetNativePush.ACTION_REFRESH))

        assertTrue(logged.any { it.first.contains("BgWidgetProvider.render") })
    }

    @Test
    fun `an unrelated action falls through without throwing`() {
        // No widgets installed, no ACTION_REFRESH -- exercises the super.onReceive()
        // branch instead.
        BgWidgetProvider().onReceive(app, Intent("some.other.action"))
    }
}
