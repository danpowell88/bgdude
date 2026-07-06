---
id: TASK-202
title: 'PumpService.onDestroy: tear down BLE handler and Garmin SDK'
status: To Do
assignee: []
created_date: '2026-07-06 21:10'
labels:
  - code-health
  - native
  - pump
milestone: m-8
dependencies: []
priority: medium
ordinal: 111600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `android/app/src/main/kotlin/com/bgdude/app/pump/PumpService.kt` has no `onDestroy` override — `commHandler` (created at line 55) and `GarminIntegration.init` (line 56) are never stopped on service destruction (`stop()` at line 83 is only reachable via the command channel).

**Reason for change.** Repeated restart cycles can accumulate BLE scan state and Connect IQ connections; the ongoing notification is never reconciled.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 onDestroy stops the comm handler, shuts down Garmin, and clears references
- [ ] #2 Robolectric test asserts onDestroy invokes commHandler.stop()
- [ ] #3 `cd android && ./gradlew :app:testDebugUnitTest` green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add an `onDestroy` override to `PumpService.kt` that stops `commHandler`, shuts down the Garmin integration, and clears references
- Reconcile/remove the ongoing notification on destroy
- Add a Robolectric test asserting onDestroy invokes commHandler.stop()
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify native: `cd android && ./gradlew :app:testDebugUnitTest` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (native finding 7)
- Effort: S
- Where: `android/app/src/main/kotlin/com/bgdude/app/pump/PumpService.kt`
- Related: TASK-178, TASK-186
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
