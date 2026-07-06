---
id: TASK-129
title: Await model restore before training (incumbent race)
status: To Do
assignee: []
created_date: '2026-07-06 08:38'
labels:
  - code-health
  - ml
milestone: m-5
dependencies: []
priority: high
ordinal: 129000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The forecaster store constructor fires `_restore()` unawaited (`lib/ml/forecaster_service.dart:80-89,106-119,128-140`); if `trainForecaster()` (`lib/state/providers.dart:2059`) runs first, the incumbent is `NoResidualModel`, so the candidate never A/Bs against the on-disk model and can overwrite it; a late restore can clobber fresh in-memory state.

**Reason for change.** The promotion gate is only meaningful against the real incumbent; the race lets an untested candidate replace a good persisted model.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `train()` awaits the stored restore future
- [ ] #2 `_restore()` never overwrites a newer in-memory model
- [ ] #3 Test: training immediately after construction with a trained model on disk A/Bs against that incumbent
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
