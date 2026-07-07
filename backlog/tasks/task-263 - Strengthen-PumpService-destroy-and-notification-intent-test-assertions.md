---
id: TASK-263
title: Strengthen PumpService destroy and notification-intent test assertions
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 17:30'
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
- [ ] #1 PumpServiceDestroyTest verifies the Garmin SDK shutdown and the BLE central close/disconnect happened
- [ ] #2 PumpServiceNotificationIntentTest asserts the contentIntent is immutable and targets MainActivity
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-202 and TASK-203)
- Files: android/app/src/test/kotlin/com/bgdude/app/pump/PumpServiceDestroyTest.kt, PumpServiceNotificationIntentTest.kt
- The TASK-203 production code is correct (FLAG_IMMUTABLE, singleTop MainActivity, unique request code); this only hardens the tests
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
