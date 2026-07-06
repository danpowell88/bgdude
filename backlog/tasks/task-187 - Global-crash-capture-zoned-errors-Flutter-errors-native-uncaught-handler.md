---
id: TASK-187
title: 'Global crash capture: zoned errors, Flutter errors, native uncaught handler'
status: To Do
assignee: []
created_date: '2026-07-06 12:55'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - logging
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 101400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Grep confirms zero global error handling anywhere: no `runZonedGuarded`, no `FlutterError.onError` customisation, no `PlatformDispatcher.instance.onError` in lib/, and no `Thread.setDefaultUncaughtExceptionHandler` in the Kotlin service. An uncaught async error (e.g. a bad KV decode in a fire-and-forget `_restore()`) vanishes silently; a fatal crash overnight leaves no trace to diagnose next morning. The app is on-device-only by design (no Crashlytics), so capture must be local.

**Reason for change.** For an unattended glucose monitor, silent-death and no-trace crashes are the worst diagnostic failure. Every uncaught error should be persisted locally and visible.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 runApp wrapped in runZonedGuarded; FlutterError.onError and PlatformDispatcher.onError route to the on-device log with stack traces
- [ ] #2 Kotlin: a default uncaught-exception handler persists the crash (timestamp, thread, stack) to app-local storage before the process dies
- [ ] #3 A "last crash" entry is visible on the Developer screen log surface
- [ ] #4 Test: a thrown uncaught async error is captured and persisted
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Wire runZonedGuarded + FlutterError.onError + PlatformDispatcher.onError in main.dart routing to the TASK-38 log (create a minimal sink if TASK-38 has not landed).
- Add Thread.setDefaultUncaughtExceptionHandler in the Application/service init chaining to the previous handler.
- Surface the last persisted crash on the Developer screen (TASK-81 home).
- Test the Dart capture path with an injected uncaught error.
- Verify: `flutter analyze` clean, `flutter test` green; `gradlew :app:testDebugUnitTest` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep 2026-07-06 (verified: zero handlers present)
- Effort: S–M
- Where: lib/main.dart, lib/app.dart, android/.../BgdudeApplication or PumpService init
- Related: TASK-38 (log ring buffer), TASK-81 (developer surface)
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
