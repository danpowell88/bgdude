---
id: TASK-135
title: Enforce weighted minimum leaf mass in GBM splits
status: To Do
assignee: []
created_date: '2026-07-06 08:39'
updated_date: '2026-07-06 12:58'
labels:
  - code-health
  - ml
milestone: m-8
dependencies: []
priority: low
ordinal: 110200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `minSamplesLeaf` (`lib/ml/gbm.dart:124`) is documented as minimum weighted row count but `_bestSplit` (`:288-296`) gates on raw counts; with near-zero sample weights a leaf can pass the floor while carrying almost no effective weight, producing high-variance leaf values.

**Reason for change.** The doc and the implementation disagree; either can be right, but the mismatch hides a variance risk under recency weighting.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Either minimum weighted sum per child is enforced (with the parameter renamed accordingly) or the doc is corrected and a separate `minLeafWeight` added — the decision is documented
- [ ] #2 A test with heavy weight imbalance covers the chosen behaviour
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Decide: enforce weighted leaf mass (rename `minSamplesLeaf`) or correct the doc and add `minLeafWeight`.
- Implement the decision in `_bestSplit` and document it.
- Add a test with heavy weight imbalance.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/gbm.dart:124,288-296`)
- Effort: S
- Where: `lib/ml/gbm.dart`
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
