---
id: TASK-202
title: 'PumpService.onDestroy: tear down BLE handler and Garmin SDK'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:10'
updated_date: '2026-07-07 17:07'
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
- [x] #1 onDestroy stops the comm handler, shuts down Garmin, and clears references
- [x] #2 Robolectric test asserts onDestroy invokes commHandler.stop()
- [x] #3 `cd android && ./gradlew :app:testDebugUnitTest` green
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 17:01
---
Started: adding an onDestroy override to PumpService.kt to tear down commHandler and GarminIntegration.
---

author: Claude
created: 2026-07-07 17:07
---
Added PumpService.onDestroy: stops commHandler, clears the reference (so any post-destroy command wrapper call is a safe null-safe no-op), and shuts down GarminIntegration. Deliberately did NOT touch WidgetNativePush's staleness alarm here -- that's TASK-236's separate concern (cancel tied to widget removal/unpair, not service destruction) and cancelling it on every service restart would defeat TASK-177's whole point of keeping the widget honest even when the service/engine dies. Added android/.../PumpServiceDestroyTest.kt (2 Robolectric tests): the first observes PumpCommHandler.stop()'s real side effect (it unconditionally emits an IDLE connection state, which onCreate never triggers on its own, so seeing it after controller.destroy() proves onDestroy's new commHandler?.stop() call actually ran) rather than needing to mock PumpCommHandler; the second confirms commHandler is cleared to null so command methods called after destroy stay safe no-ops. gradlew :app:testDebugUnitTest green (79 tests, 0 failures). flutter analyze clean, flutter test test/ green (978 tests), flutter build apk --debug succeeded. No user-visible/screen change -- DoD #6/#7 n/a.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
