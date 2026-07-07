---
id: TASK-189
title: Guard the pumpx2 BLE callback bodies so one throw cannot kill the service
status: Done
assignee:
  - Claude
created_date: '2026-07-06 12:55'
updated_date: '2026-07-07 02:34'
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
- [x] #1 Every externally-invoked callback body is wrapped (or dispatched through a shared safeCallback helper) that catches Throwable, logs with the callback name, and returns
- [x] #2 onPumpCriticalError handling itself cannot throw
- [x] #3 JVM test: a callback that throws does not propagate; a subsequent good callback still processes
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 02:28
---
Started: add a safe(name){...} helper in PumpCommHandler catching Throwable with the callback name logged; wrap every externally-invoked callback body; JVM test proves a throwing callback doesn't propagate and later callbacks still process.
---

author: Claude
created: 2026-07-07 02:34
---
Done (commit fda553d).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
New SafeCallbacks object (injectable logSink because android.util.Log is a throwing stub in JVM tests): run(name){} and run(name, fallback){} catch Throwable, log the callback name, and never propagate — the report path itself is guarded so even a broken sink can't throw (AC#2 covers onPumpCriticalError). All 11 TandemPump overrides in PumpCommHandler now route through safe(...): the Boolean callbacks fail OPEN (onPumpDiscovered -> attempt connection, onPumpDisconnected -> keep auto-reconnect). onReceiveMessage's old partial try became the same guard with the message class name in the log. 5 JVM tests incl. throw-then-recover and the broken-sink case. Verified: gradlew :app:testDebugUnitTest green, debug APK builds, analyze clean, 666 Dart tests green. Commit fda553d.
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
