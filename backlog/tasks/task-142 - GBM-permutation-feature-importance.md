---
id: TASK-142
title: GBM permutation feature importance
status: To Do
assignee: []
created_date: '2026-07-06 08:41'
labels:
  - feature
  - ml
  - developer
milestone: m-5
dependencies: []
priority: medium
ordinal: 142000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The residual GBM exposes zero interpretability while the ridge sensitivity model already exposes importance (`lib/ml/ridge_regression.dart:39-42`); held-out permutation importance (shuffle one feature column, measure RMSE increase) would show which features drive the correction, help prune dead features (as feature v4 did manually), and act as a drift signal.

**Value.** Makes the residual model inspectable: which features actually earn their place, and when their contribution shifts.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A `permutationImportance(holdout)` method exists in the trainer using the existing held-out rows
- [ ] #2 Top features are surfaced in the model report/accuracy screen
- [ ] #3 A unit test on a synthetic dataset with one informative feature passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Implement `permutationImportance(holdout)` in the trainer over the existing held-out rows.
- Surface the top features in the model report/accuracy screen.
- Add a unit test with a synthetic dataset where exactly one feature is informative.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/ridge_regression.dart:39-42`)
- Effort: M
- Where: `lib/ml/forecaster_training.dart`, model report/accuracy screen
- Related: complements TASK-59
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
