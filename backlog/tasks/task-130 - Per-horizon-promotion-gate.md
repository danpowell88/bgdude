---
id: TASK-130
title: Per-horizon promotion gate
status: To Do
assignee: []
created_date: '2026-07-06 08:38'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - ml
milestone: m-5
dependencies: []
priority: high
ordinal: 102500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `baselinePairs`/`candidatePairs`/`incumbentPairs` (`lib/ml/forecaster_training.dart:186-217`) pool all horizons (30/60/120) into one `ModelEvaluation` (`lib/ml/model_registry.dart:74,85-114`), so RMSE/Clarke/hypo stats are mixed-horizon and a candidate that improves 30-min but regresses 120-min still passes; `minSampleCount = 288` is checked on the pool (~96 per horizon). `AccuracyAnalyzer` already reports per-horizon (`lib/ml/accuracy_report.dart:34-43`).

**Reason for change.** Pooled gating can promote a model that is worse at the clinically important long horizon; the gate must judge each horizon on its own evidence.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each horizon is evaluated and gated independently (promote per-horizon or all-pass; the choice is documented)
- [ ] #2 `minSampleCount` is applied per horizon
- [ ] #3 Test: a candidate that wins the short horizon but regresses the long one is not promoted (or only the winning horizon is)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Split evaluation pairs by horizon and produce a `ModelEvaluation` per horizon.
- Decide and document per-horizon promotion vs all-pass; implement it in the gate.
- Apply `minSampleCount` per horizon.
- Add the mixed-outcome promotion test.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/forecaster_training.dart:186-217`)
- Effort: M
- Where: `lib/ml/forecaster_training.dart`, `lib/ml/model_registry.dart`
- Related: TASK-19, TASK-55 (fold into its fold work if concurrent)
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
