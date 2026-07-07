---
id: TASK-135
title: Enforce weighted minimum leaf mass in GBM splits
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:39'
updated_date: '2026-07-07 15:18'
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
- [x] #1 Either minimum weighted sum per child is enforced (with the parameter renamed accordingly) or the doc is corrected and a separate `minLeafWeight` added — the decision is documented
- [x] #2 A test with heavy weight imbalance covers the chosen behaviour
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 15:12
---
Started: reviewing lib/ml/gbm.dart minSamplesLeaf doc vs _bestSplit implementation to fix the raw-count vs weighted-mass mismatch.
---

author: Claude
created: 2026-07-07 15:18
---
Decision (per AC#1): enforce the weighted floor, not correct the doc -- the doc's stated intent (weighted row count) was the actually-desired behavior; the implementation was the bug. Renamed minSamplesLeaf (int) -> minLeafWeight (double, default 5.0, numerically identical to the old default when all weights are 1.0) in GbmRegressor and ResidualGbmTrainer; _bestSplit now gates directly on leftW/rightW (the weighted sums already being computed) instead of leftCount/rightCount, which are gone. Since minLeafWeight is embedded in GbmRegressor.toJson()/fromJson() and that blob is persisted (ModelRuns), bumped ResidualGbmModel.schemaVersion 1->2 so any older on-disk model blob is rejected by the EXISTING version-mismatch guard (safe fail -> NoResidualModel, forces a retrain) rather than crashing on the renamed JSON key. Added a test (AC#2): two 5-row clusters separated by a single candidate split, left cluster weight 0.001/row (sum 0.005) vs right cluster weight 1.0/row (sum 5.0) -- under the OLD int-count guard both sides (5 rows each) would have passed and produced a real split; the fixed guard rejects it (0.005 << minLeafWeight=5.0), leaving a single root leaf, verified by both clusters predicting the identical overall weighted mean. A control case with minLeafWeight lowered to 0.001 confirms the same data DOES split when the floor allows it (proves the guarded case is testing the floor, not an unrelated flatness). flutter analyze clean, flutter test test/ green (943 tests), flutter build apk --debug succeeded. No user-visible/native/screen changes -- DoD #5/#6/#7 n/a.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
