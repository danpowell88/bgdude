---
id: TASK-189
title: Guard the pumpx2 BLE callback bodies so one throw cannot kill the service
status: To Do
assignee: []
created_date: '2026-07-06 12:55'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - native
  - pump
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 101600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `PumpCommHandler.kt` implements ~12 pumpx2/BLE callbacks (`onReceiveMessage` :207, `onReceiveQualifyingEvent` :265, `onPumpConnected` :303, `onPumpDisconnected` :351, `onPumpCriticalError` :361, ...) with only a single `try {` in the whole file. These callbacks run on BLE library threads: an uncaught Kotlin exception there (decode edge, unexpected null, mapper bug) crashes the whole process — the foreground service dies and glucose monitoring stops.

**Reason for change.** The service process must survive any single malformed message or callback edge case; failures should be logged and skipped, not fatal.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every externally-invoked callback body is wrapped (or dispatched through a shared safeCallback helper) that catches Throwable, logs with the callback name, and returns
- [ ] #2 onPumpCriticalError handling itself cannot throw
- [ ] #3 JVM test: a callback that throws does not propagate; a subsequent good callback still processes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a `private inline fun safe(name: String, block: () -> Unit)` helper logging failures.
- Wrap each override body; keep behaviour identical otherwise.
- Add the throw-then-recover JVM test.
- Verify: `gradlew :app:testDebugUnitTest` green; `flutter build apk --debug` OK.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep 2026-07-06 (verified: 12 overrides, 1 try block)
- Effort: S–M
- Where: android/app/src/main/kotlin/com/bgdude/app/pump/PumpCommHandler.kt:207-370
- Related: TASK-114 (extraction — coordinate), TASK-11 (done, looper marshalling)
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
