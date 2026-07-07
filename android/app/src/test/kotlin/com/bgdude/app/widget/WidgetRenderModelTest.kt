package com.bgdude.app.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * TASK-177: the widget's grey-out and native formatting decisions, JVM-tested (the
 * render logic is extracted pure instead of pulling in Robolectric — the RemoteViews
 * layer is a thin passthrough of these values).
 */
class WidgetRenderModelTest {

    private val now = 1_751_800_000_000L

    @Test
    fun `a fresh in-range reading renders green with its age`() {
        val r = WidgetRenderModel.render(
            range = WidgetRenderModel.RANGE_IN_RANGE,
            cgmEpochMs = now - 3 * 60_000,
            nowMs = now,
        )
        assertFalse(r.stale)
        assertEquals(WidgetRenderModel.COLOR_IN_RANGE, r.primaryColor)
        assertEquals("3m ago", r.updatedText)
    }

    @Test
    fun `past the staleness threshold everything greys out — even a green range`() {
        // The frozen-but-green failure mode: last value in range, engine dead,
        // reading 40 minutes old. The render MUST grey out.
        val r = WidgetRenderModel.render(
            range = WidgetRenderModel.RANGE_IN_RANGE,
            cgmEpochMs = now - 40 * 60_000,
            nowMs = now,
        )
        assertTrue(r.stale)
        assertEquals(WidgetRenderModel.COLOR_STALE, r.primaryColor)
        assertEquals(WidgetRenderModel.COLOR_STALE, r.secondaryColor)
        assertEquals("Stale · 40m ago", r.updatedText)
    }

    @Test
    fun `exactly at the threshold is still fresh, one past greys out`() {
        val atLimit = WidgetRenderModel.render(
            range = WidgetRenderModel.RANGE_LOW,
            cgmEpochMs = now - WidgetRenderModel.STALE_AFTER_MINUTES * 60_000,
            nowMs = now,
        )
        assertFalse(atLimit.stale)
        assertEquals(WidgetRenderModel.COLOR_LOW, atLimit.primaryColor)

        val past = WidgetRenderModel.render(
            range = WidgetRenderModel.RANGE_LOW,
            cgmEpochMs = now - (WidgetRenderModel.STALE_AFTER_MINUTES + 1) * 60_000,
            nowMs = now,
        )
        assertTrue(past.stale)
    }

    @Test
    fun `no reading at all is stale with a no-data label`() {
        val r = WidgetRenderModel.render(range = null, cgmEpochMs = null, nowMs = now)
        assertTrue(r.stale)
        assertEquals("no data", r.updatedText)
        assertEquals(WidgetRenderModel.COLOR_STALE, r.primaryColor)
    }

    @Test
    fun `native field formatting mirrors the Dart formatter`() {
        val mmol = WidgetRenderModel.fields(
            cgmMgdl = 120, trend = "flat", iobUnits = 1.25, unitLabel = "mmol/L")
        assertEquals("6.7", mmol.bgText)
        assertEquals("→", mmol.trendArrow)
        assertEquals("IOB 1.3 U", mmol.iobText)
        assertEquals(WidgetRenderModel.RANGE_IN_RANGE, mmol.range)

        val mgdl = WidgetRenderModel.fields(
            cgmMgdl = 65, trend = "doubleDown", iobUnits = null, unitLabel = "mg/dL")
        assertEquals("65", mgdl.bgText)
        assertEquals("⇊", mgdl.trendArrow)
        assertEquals("IOB --", mgdl.iobText)
        assertEquals(WidgetRenderModel.RANGE_LOW, mgdl.range)

        val none = WidgetRenderModel.fields(
            cgmMgdl = null, trend = null, iobUnits = null, unitLabel = null)
        assertEquals("--", none.bgText)
        assertEquals("", none.trendArrow)
        assertEquals(WidgetRenderModel.RANGE_UNKNOWN, none.range)
    }
}
