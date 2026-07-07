---
id: TASK-6
title: Advisor hard low-guard on current reading + compression-low exclusion
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:06'
labels:
  - roadmap
  - dosing-math
  - "\U0001F512 safety"
milestone: m-0
dependencies: []
priority: high
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The bolus calculator ("advisor") can suggest a correction dose even when your current reading is already low, and it does not filter out "compression lows" — false low readings caused by lying on the sensor and squashing it.

**Reason for change.** Recommending insulin while you are genuinely low is dangerous; treating a compression-low as real is the opposite mistake. "Treat the low first, and don't trust a squashed-sensor reading" is a basic safety guard the advisor is missing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Advisor blocks/warns before dosing into a current low
- [x] #2 Compression-low readings excluded from the guard
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- In `bolus_advisor.dart:183` add a hard low-guard on the current reading (block/warn before any correction).
- Exclude compression-low readings from the guard (reuse the compression-low detector).
- Unit tests: correction blocked when current BG < guard; compression-low reading does not trigger the guard. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able).
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1, P0-6
- Effort: S
- Where: `bolus_advisor.dart:183`
- Flags: 🔒 safety
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added a hard low-guard in `bolus_advisor.dart` that blocks/warns before suggesting a correction when the current reading is low, with compression-low readings (via the compression-low detector) excluded from triggering it. Landed in commit 5c974df (P0 dosing-math fixes) with unit tests for both behaviours; `flutter analyze` clean and `flutter test` green.
<!-- SECTION:FINAL_SUMMARY:END -->
