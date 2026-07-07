---
id: TASK-133
title: Reconciliation must skip warm-up and compression-low artifacts
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:39'
updated_date: '2026-07-07 04:05'
labels:
  - code-health
  - ml
  - data-integrity
milestone: m-5
dependencies: []
priority: medium
ordinal: 106500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `reconcilePredictions` (`lib/data/history_repository.dart:322-332`) picks the nearest CGM within ±5 min as ground truth without skipping `sensorWarmup`/`compressionLow` rows, while training labels do exclude them (`lib/ml/forecaster_training.dart:85`) — accuracy reports and live-RMSE recalibration are polluted by exactly the artifacts training drops.

**Reason for change.** Reconciling against artifact readings skews accuracy metrics and the live uncertainty recalibration that feeds alert bands.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Warm-up, compression-low and `mgdl <= 0` rows are filtered before nearest-actual selection
- [x] #2 Reconciliation is skipped when no valid rows remain
- [x] #3 A test asserts a compression-low nadir is not chosen
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Filter `sensorWarmup`/`compressionLow`/`mgdl <= 0` rows before nearest-actual selection in `reconcilePredictions`.
- Skip reconciliation when no valid rows remain in the window.
- Add a test with a compression-low nadir near the target time.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/data/history_repository.dart:322-332`)
- Effort: S
- Where: `lib/data/history_repository.dart`
- Related: TASK-92
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 04:02
---
Started: filter warm-up/compression-low/nonpositive rows before nearest-actual selection in reconcilePredictions (both repo impls), skip when none valid, compression-low-nadir test.
---

author: Claude
created: 2026-07-07 04:05
---
Done.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Both DriftHistoryRepository and InMemoryHistoryRepository filter sensorWarmup/compressionLow/mgdl<=0 rows before nearest-actual selection; a window with only artifacts leaves the prediction unscored (better unscored than wrong). Tests: compression-low nadir exactly on target loses to the real reading 4 min away; artifact-only window updates nothing. Verified: analyze clean, 717 tests green, APK builds.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
