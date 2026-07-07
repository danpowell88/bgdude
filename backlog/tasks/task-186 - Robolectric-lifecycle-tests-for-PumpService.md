---
id: TASK-186
title: Robolectric lifecycle tests for PumpService
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:20'
updated_date: '2026-07-07 11:11'
labels:
  - code-health
  - native
  - testing
milestone: m-8
dependencies:
  - TASK-178
priority: medium
ordinal: 108600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `android/app/src/test` covers mappers/probe/snapshot only — there are zero tests for `PumpService` lifecycle (notification channel created before `startForeground`, boot-receiver path) or `PumpCommHandler.onPumpDisconnected` reconnect behaviour; these are the state machines that keep monitoring alive for days.

**Reason for change.** The longest-running, hardest-to-reproduce failure modes live in exactly the code with no test harness.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Robolectric tests: channel-before-startForeground, boot path with/without BT permission
- [x] #2 Reconnect-on-disconnect behaviour test (may need the TASK-178 extraction)
- [x] #3 Gradle tests green in CI (blocking per the CI ticket TASK-159)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add Robolectric test scaffolding for `PumpService` (channel created before `startForeground`, boot-receiver path with and without BT permission).
- Add a reconnect-on-disconnect behaviour test for `PumpCommHandler.onPumpDisconnected`, building on the TASK-178 extraction if needed.
- Verify: `flutter analyze` clean, `flutter test` green, `cd android && ./gradlew :app:testDebugUnitTest` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 13)
- Effort: M
- Where: `android/app/src/test/`, `PumpService.kt`, `PumpCommHandler.kt`
- Related: TASK-12, TASK-178
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 11:11
---
Done: added Robolectric (4.13, sdk=[34]) + Mockito (5.14.2) to android/app/build.gradle (testOptions.unitTests.includeAndroidResources = true). Three new test classes in android/app/src/test/kotlin/com/bgdude/app/pump/: PumpServiceLifecycleTest (both notification channels exist right after onCreate — before any startCommand — and startForeground only actually fires once BLUETOOTH_CONNECT is granted, Android 12+ gate); BootReceiverTest (no service start without the permission; starts PumpService with EXTRA_AUTO_RECONNECT when granted; ignores unrelated actions); PumpCommHandlerReconnectTest (onPumpDisconnected always emits DISCONNECTED and returns true — request reconnect — verified for both a normal and an unusual HciStatus, using a mocked BluetoothPeripheral since blessed-android's class has no public constructor). DoD #1 N/A (no Dart generated code involved) and #7 N/A (native-only, no screen/flow changed). Pipeline green: gradlew testDebugUnitTest — all 8 new tests pass, 0 failures; flutter analyze clean; flutter build apk --debug succeeds.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
