package com.bgdude.app.pump

/**
 * Pure history-backfill range arithmetic, extracted from PumpCommHandler so the
 * off-by-one-prone math is unit-testable without a live BLE handler (TASK-114).
 *
 * The pump reports the sequence numbers currently in its History Log as
 * [firstSeq]..[lastSeq]. To backfill the most recent [requestedCount] entries we ask for a
 * ranged window ending at [lastSeq]; the start is clamped so it never precedes the oldest
 * entry the pump still holds.
 */
object HistoryRangePlanner {

    data class Range(val start: Long, val count: Int)

    /**
     * The ranged request to send for the most-recent [requestedCount] entries, or null when
     * there is nothing to ask for ([requestedCount] <= 0). The start is
     * `lastSeq - count + 1` coerced up to [firstSeq]; [requestedCount] is preserved (the
     * pump returns only what it holds), matching the original inline behaviour.
     */
    fun plan(firstSeq: Long, lastSeq: Long, requestedCount: Int): Range? {
        if (requestedCount <= 0) return null
        val start = (lastSeq - requestedCount + 1).coerceAtLeast(firstSeq)
        return Range(start, requestedCount)
    }
}
