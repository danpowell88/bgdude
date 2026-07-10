---
id: TASK-163
title: Add MARD to model evaluation and the accuracy screen
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 09:14'
updated_date: '2026-07-10 11:57'
labels:
  - feature
  - ml
milestone: m-5
dependencies: []
priority: medium
ordinal: 702900
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `ModelEvaluator` (`lib/ml/model_registry.dart:118-141`) computes RMSE correctly, but MARD — mean of |pred−ref|/ref, the field-standard CGM/forecast accuracy metric — does not exist anywhere in `lib/`, so forecast quality cannot be compared to the ~9-10% MARD literature bar and scale-dependent error at low glucose is hidden.

**Value.** MARD is the one accuracy number users and clinicians expect and can benchmark against published CGM performance.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `mardPercent = mean(|pred−ref|/ref)*100` on `ModelEvaluation`, guarding ref>0
- [ ] #2 MARD surfaced per horizon on the accuracy screen
- [ ] #3 Test pins pairs (100→110),(200→180) → MARD 10.0%
- [ ] #4 User guide updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `mardPercent` to `ModelEvaluation` in `lib/ml/model_registry.dart`, computed alongside RMSE with a ref>0 guard.
- Surface MARD per horizon on the accuracy screen.
- Add a unit test pinning pairs (100→110),(200→180) → MARD 10.0%.
- Update `doc/user-guide.html` accuracy-screen section.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (accuracy finding 3)
- Effort: M
- Where: `lib/ml/model_registry.dart`, accuracy screen widgets, `doc/user-guide.html`
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-10 11:57
---
branch: task-163
---
<!-- COMMENTS:END -->

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
