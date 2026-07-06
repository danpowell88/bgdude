---
id: TASK-5
title: P0-5 Rescue-carb calc uses bolus-only IOB
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 05:24'
labels:
  - roadmap
  - §1-P0
  - phase-0
  - dosing-math
dependencies: []
priority: high
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** When your glucose is low, bgdude suggests how many grams of fast carbs to eat to recover. To avoid over-treating, it subtracts the insulin still working ("insulin on board", IOB) from that estimate. But it uses total IOB, which includes the slow all-day "basal" insulin the pump delivers.

**Reason for change.** Counting basal as active insulin makes the app think more insulin is fighting the low than there is, so it suggests eating more carbs than needed — risking a rebound high. It should use only the "bolus" (meal/correction) insulin, as P0-1 does.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Rescue carbs computed from bolus-only IOB
- [x] #2 Test: phantom basal no longer inflates rescue carbs
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- In `rescue_carbs.dart:56` use bolus-only IOB for the subtraction (same distinction as P0-1).
- Unit test: identical low with only basal IOB yields fewer rescue carbs than with equivalent bolus IOB. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able).
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §1 P0-5
- Effort: S
- Where: rescue_carbs.dart:56
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Rescue-carb calculation in `rescue_carbs.dart` now subtracts bolus-only IOB instead of total IOB including basal, so phantom basal no longer inflates the suggested carbs. Landed in commit 5c974df (P0 dosing-math fixes) with a regression unit test; `flutter analyze` clean and `flutter test` green.
<!-- SECTION:FINAL_SUMMARY:END -->
