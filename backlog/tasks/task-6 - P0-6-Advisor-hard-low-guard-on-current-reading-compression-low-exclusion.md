---
id: TASK-6
title: P0-6 Advisor hard low-guard on current reading + compression-low exclusion
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 04:12'
labels:
  - roadmap
  - §1-P0
  - phase-0
  - dosing-math
  - "\U0001F512 safety"
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
- [ ] #1 Advisor blocks/warns before dosing into a current low
- [ ] #2 Compression-low readings excluded from the guard
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** In bolus_advisor.dart:183 add a hard low-guard on the current reading (block/warn before any correction) and exclude compression-low readings (reuse the compression-low detector).

**Testing.** Unit tests: correction blocked when current BG < guard; compression-low reading does not trigger the guard. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able). `flutter analyze` clean and `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §1 P0-6
- Effort: S
- Where: bolus_advisor.dart:183
- Flags: 🔒 safety
- Roadmap status: open
<!-- SECTION:NOTES:END -->
