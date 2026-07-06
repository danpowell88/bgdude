---
id: TASK-23
title: Health-feature look-ahead leak + _activityAt binary search
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:06'
labels:
  - roadmap
  - ml
  - data-integrity
milestone: m-5
dependencies: []
priority: medium
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude blends in health data (sleep, heart rate, activity) to sharpen forecasts. Two bugs exist in how it builds those inputs: the "resting heart rate" baseline is computed using future readings the model wouldn't have at prediction time (a "look-ahead leak"), and finding the active workout uses a slow linear scan.

**Reason for change.** A look-ahead leak makes the model look more accurate in testing than it can ever be in real use, which is misleading and unsafe to rely on. It should only use past readings.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Resting-HR baseline uses trailing samples only (no look-ahead)
- [x] #2 _activityAt uses binary search over sorted samples
- [x] #3 Feature values unchanged except for the removed leak
- [x] #4 Test asserts no future sample influences a feature
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- In `health_features.dart` / `HealthFeatureSampler`, compute the resting-HR baseline from TRAILING samples only (no look-ahead).
- Replace the `_activityAt` linear scan with a binary search over the sorted sample list.
- Test: assert no future sample influences a feature; feature values otherwise unchanged; binary-search correctness test.
- Run ML-honesty tests first (coverage + bias, synthetic-data recovery).
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1 P2-7
- Effort: S–M
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed the health-feature look-ahead leak in `lib/ml/health_features.dart`: the resting-HR baseline is now computed trailing (readings at or before the query time) so historical training features never see future readings, and `_activityAt` binary-searches the trailing (from, t] window instead of scanning the whole sorted list (identical values, O(log n)). Verified by tests that a future resting-HR reading no longer changes a past feature and the activity window sum is exact; analyze clean (commit cd10167).
<!-- SECTION:FINAL_SUMMARY:END -->
