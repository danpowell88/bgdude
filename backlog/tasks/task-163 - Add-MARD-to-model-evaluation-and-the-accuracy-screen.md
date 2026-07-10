---
id: TASK-163
title: Add MARD to model evaluation and the accuracy screen
status: Review
assignee:
  - Claude
created_date: '2026-07-06 09:14'
updated_date: '2026-07-10 12:06'
status: Needs Review
assignee:
  - Claude
created_date: '2026-07-06 09:14'
updated_date: '2026-07-10 14:03'
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
- [x] #1 `mardPercent = mean(|pred−ref|/ref)*100` on `ModelEvaluation`, guarding ref>0
- [x] #2 MARD surfaced per horizon on the accuracy screen
- [x] #3 Test pins pairs (100→110),(200→180) → MARD 10.0%
- [x] #4 User guide updated
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

author: Claude
created: 2026-07-10 12:06
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- code complete and pushed to branch task-163 (commit 576f151).
created: 2026-07-10 12:07
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- code complete and pushed to branch task-163 (commit b8b9fa9).

ModelEvaluation gained mardPercent (mean(|pred-ref|/ref)*100, ref>0 guarded, computed in ModelEvaluator.evaluate alongside RMSE). Surfaced on BOTH screens that render per-horizon ModelEvaluation stats -- Settings->Forecast accuracy (model_accuracy_screen.dart) and Reports->Model performance (model_report_screen.dart) -- since both share the same construct.

Tests: new test/ml/model_evaluator_test.dart (pins the ticket's (100->110),(200->180)->10.0% example, zero-reference exclusion, empty-list and perfect-prediction edges); rigor-checked by removing the ref>0 guard and confirming the zero-reference test fails with Infinity, then reverting. Extended the two integration tests that already open these screens to assert MARD renders.

flutter analyze clean, flutter test --coverage green (1370 tests), coverage 68.73% (floor 65%), flutter build apk --debug succeeded. doc/user-guide.html updated (Reports table + Settings > Forecast accuracy bullet).

friction:none -- straightforward once the two render sites were located via grep; no build/env/tooling issues this task.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
