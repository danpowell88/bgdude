---
id: TASK-263
title: Strengthen PumpService destroy and notification-intent test assertions
status: Done
assignee:
  - Claude
created_date: '2026-07-07 17:30'
updated_date: '2026-07-08 03:23'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 158000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two native lifecycle tests under-assert, so half of what the commits added is unguarded. PumpServiceDestroyTest asserts an IDLE state emission and post-destroy null-safety but never verifies GarminIntegration.shutdown() / ConnectIQ.shutdown() was called nor that the BLE central was closed, so a regression dropping the Garmin teardown (half of TASK-202) would stay green. PumpServiceNotificationIntentTest asserts only contentIntent != null; it does not assert FLAG_IMMUTABLE or that the intent targets MainActivity, so a regression to FLAG_MUTABLE (which crashes on API 31+) or a wrong target Activity would not be caught. Robolectric shadowOf(pendingIntent) exposes the saved intent and mutability, so both are checkable.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 PumpServiceDestroyTest verifies the Garmin SDK shutdown and the BLE central close/disconnect happened
- [x] #2 PumpServiceNotificationIntentTest asserts the contentIntent is immutable and targets MainActivity
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-202 and TASK-203)
- Files: android/app/src/test/kotlin/com/bgdude/app/pump/PumpServiceDestroyTest.kt, PumpServiceNotificationIntentTest.kt
- The TASK-203 production code is correct (FLAG_IMMUTABLE, singleTop MainActivity, unique request code); this only hardens the tests
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 03:15
---
Started: strengthening PumpServiceDestroyTest (Garmin shutdown + BLE central close assertions) and PumpServiceNotificationIntentTest (FLAG_IMMUTABLE + MainActivity target) via Robolectric shadows.
---

author: Claude
created: 2026-07-08 03:23
---
Fixed both:

AC#1 (Garmin/BLE teardown): added a new PumpServiceDestroyTest asserting the ACTUAL teardown, not just its absence-of-crash side effects. Needed two small internal (not private) accessors, matching the existing PumpCommHandler.bluetoothHandler precedent for exactly this class of test: GarminIntegration.hasSender (sender != null) and PumpService.commHandler (was private var, now internal var with private set). The test captures the commHandler reference BEFORE destroy() nulls PumpService's own field, then asserts the CAPTURED handler's own bluetoothHandler is null post-destroy (proving the BLE central was actually closed, not just that the outer reference was dropped) and that GarminIntegration.hasSender flips false (proving shutdown() ran).

AC#2 (notification intent hardening): added assertOpensMainActivityImmutably(), checking shadowOf(intent).isImmutable and shadowOf(intent).savedIntent.component?.className == MainActivity's name via Robolectric's ShadowPendingIntent (confirmed its API via javap on the cached shadows-framework jar first). Applied to both existing tests (ongoing-connection and urgent-low-backstop notifications).

Rigor check (3 separate injected bugs, each reverted after): (1) commented out GarminIntegration.shutdown() in onDestroy -- new test failed exactly as predicted; (2) commented out commHandler?.destroy() -- both the new test AND an existing one (IDLE-emission) correctly failed; (3) flipped FLAG_IMMUTABLE to FLAG_MUTABLE -- both notification tests correctly failed on the isImmutable assertion. git diff on all three production files is clean after reverting.

Verified: gradlew :app:testDebugUnitTest green (full suite), flutter analyze clean, flutter test test/ green (1158, unaffected -- native-only change), flutter build apk --debug succeeds. No user-guide update (internal test hardening, no user-visible surface).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
