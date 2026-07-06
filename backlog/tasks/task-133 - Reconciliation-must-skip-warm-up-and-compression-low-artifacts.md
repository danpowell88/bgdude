---
id: TASK-133
title: Reconciliation must skip warm-up and compression-low artifacts
status: To Do
assignee: []
created_date: '2026-07-06 08:39'
labels:
  - code-health
  - ml
  - data-integrity
milestone: m-5
dependencies: []
priority: medium
ordinal: 133000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `reconcilePredictions` (`lib/data/history_repository.dart:322-332`) picks the nearest CGM within ±5 min as ground truth without skipping `sensorWarmup`/`compressionLow` rows, while training labels do exclude them (`lib/ml/forecaster_training.dart:85`) — accuracy reports and live-RMSE recalibration are polluted by exactly the artifacts training drops.

**Reason for change.** Reconciling against artifact readings skews accuracy metrics and the live uncertainty recalibration that feeds alert bands.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Warm-up, compression-low and `mgdl <= 0` rows are filtered before nearest-actual selection
- [ ] #2 Reconciliation is skipped when no valid rows remain
- [ ] #3 A test asserts a compression-low nadir is not chosen
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
