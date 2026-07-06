package com.bgdude.app.pump

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Boundary tests for the extracted history-range arithmetic (TASK-114). */
class HistoryRangePlannerTest {

    @Test
    fun normal_window_ends_at_lastSeq() {
        // Log holds 1..100, want the most recent 10 → 91..100.
        val r = HistoryRangePlanner.plan(firstSeq = 1, lastSeq = 100, requestedCount = 10)!!
        assertEquals(91L, r.start)
        assertEquals(10, r.count)
    }

    @Test
    fun count_exceeding_available_clamps_start_to_firstSeq() {
        // Only 5 entries (1..5) but 10 requested → start pinned to firstSeq.
        val r = HistoryRangePlanner.plan(firstSeq = 1, lastSeq = 5, requestedCount = 10)!!
        assertEquals(1L, r.start)
        assertEquals(10, r.count) // preserved; the pump returns only what it holds
    }

    @Test
    fun single_entry_log() {
        val r = HistoryRangePlanner.plan(firstSeq = 7, lastSeq = 7, requestedCount = 1)!!
        assertEquals(7L, r.start)
        assertEquals(1, r.count)
    }

    @Test
    fun non_zero_first_sequence() {
        // Pump has pruned old entries: log is 500..600, want 30 → 571..600.
        val r = HistoryRangePlanner.plan(firstSeq = 500, lastSeq = 600, requestedCount = 30)!!
        assertEquals(571L, r.start)
        assertEquals(30, r.count)
    }

    @Test
    fun zero_or_negative_count_is_nothing_to_fetch() {
        assertNull(HistoryRangePlanner.plan(1, 100, 0))
        assertNull(HistoryRangePlanner.plan(1, 100, -5))
    }

    @Test
    fun empty_log_does_not_underflow_before_firstSeq() {
        // Degenerate: lastSeq < firstSeq. Start must still not precede firstSeq.
        val r = HistoryRangePlanner.plan(firstSeq = 10, lastSeq = 5, requestedCount = 3)!!
        assertEquals(10L, r.start)
    }
}
