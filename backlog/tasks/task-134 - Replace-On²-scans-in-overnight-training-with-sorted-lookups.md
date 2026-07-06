---
id: TASK-134
title: Replace O(n²) scans in overnight training with sorted lookups
status: To Do
assignee: []
created_date: '2026-07-06 08:39'
labels:
  - code-health
  - ml
milestone: m-8
dependencies: []
priority: medium
ordinal: 134000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** For each strided timestep × horizon, `_nearest` (`lib/ml/forecaster_training.dart:106-156,221-232,234-245`) linearly scans the whole sorted samples list and `_valueAt` scans the entire prediction line — tens of millions of comparisons per training run over ~30 days, growing with history.

**Reason for change.** Training cost grows quadratically with history and burns battery during the overnight job; sorted lookups make it near-linear.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Horizon targets are resolved by binary search or a forward two-pointer over the sorted list
- [ ] #2 The prediction line is indexed by fixed `stepMinutes` step offset
- [ ] #3 Training output is identical on a fixture (regression test)
- [ ] #4 The measured speedup is noted on the task
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Capture a training fixture and its current output for regression comparison.
- Replace `_nearest` scans with binary search or a forward two-pointer over the sorted samples.
- Index `_valueAt` by fixed `stepMinutes` offset into the prediction line.
- Re-run the fixture, assert identical output, and note the measured speedup.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/forecaster_training.dart:106-245`)
- Effort: M
- Where: `lib/ml/forecaster_training.dart`
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
