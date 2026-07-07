---
id: TASK-129
title: Await model restore before training (incumbent race)
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:38'
updated_date: '2026-07-07 02:48'
labels:
  - code-health
  - ml
milestone: m-5
dependencies: []
priority: high
ordinal: 102400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The forecaster store constructor fires `_restore()` unawaited (`lib/ml/forecaster_service.dart:80-89,106-119,128-140`); if `trainForecaster()` (`lib/state/providers.dart:2059`) runs first, the incumbent is `NoResidualModel`, so the candidate never A/Bs against the on-disk model and can overwrite it; a late restore can clobber fresh in-memory state.

**Reason for change.** The promotion gate is only meaningful against the real incumbent; the race lets an untested candidate replace a good persisted model.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `train()` awaits the stored restore future
- [x] #2 `_restore()` never overwrites a newer in-memory model
- [x] #3 Test: training immediately after construction with a trained model on disk A/Bs against that incumbent
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Keep the `_restore()` future on the store and await it at the top of `train()`.
- Guard `_restore()` so it never overwrites a newer in-memory model.
- Add a test that trains immediately after construction with a trained model on disk and asserts the A/B runs against that incumbent.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/forecaster_service.dart:80-140`)
- Effort: M
- Where: `lib/ml/forecaster_service.dart`
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 02:42
---
Started: keep the restore future on ForecasterModelController, await it at the top of train(), latch local writes so a late restore can't clobber newer in-memory state; test trains right after construction with a trained model on disk and asserts the A/B uses it as incumbent.
---

author: Claude
created: 2026-07-07 02:48
---
Done (commit c7594df). Note: first training on the SimulatedDay dataset does not pass the promotion gate, so the clobber test uses the debugMarkNewerLocalModel seam instead of a real promotion.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
ForecasterModelController keeps the restore future (restored); train() awaits it before capturing the incumbent, so the A/B always runs against the real persisted model. Promotion latches _hasNewerLocalModel; _restore discards its result once set, so a slow restore can never clobber newer in-memory state. Tests: train immediately after construction with a trained model on disk asserts incumbentRmse present + no promotion on an identical retrain + restored incumbent stays live; the late-restore guard proven via a @visibleForTesting latch seam. Verified: analyze clean, 674 tests green, debug APK builds. Commit c7594df.
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
