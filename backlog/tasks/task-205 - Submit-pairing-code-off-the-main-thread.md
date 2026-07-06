---
id: TASK-205
title: Submit pairing code off the main thread
status: To Do
assignee: []
created_date: '2026-07-06 21:10'
labels:
  - code-health
  - native
  - pump
milestone: m-8
dependencies: []
priority: low
ordinal: 111900
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The pump command channel handler runs on the platform main thread and calls pumpx2 `PumpState` SharedPreferences accessors that hit disk — `getJpakeDerivedSecretCached()` (`android/app/src/main/kotlin/com/bgdude/app/pump/PumpCommHandler.kt:114`), `setPairingCode` (`PumpCommHandler.kt:199`), `getPairingCodeCached()` (`PumpCommHandler.kt:294`).

**Reason for change.** Disk I/O on the main thread during pairing is a minor ANR risk.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The pairing-code submit path moves off the main thread (existing executor/handler)
- [ ] #2 The result is still marshalled back correctly
- [ ] #3 `cd android && ./gradlew :app:testDebugUnitTest` green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Move the pairing-code submit path onto the existing executor/handler used for other pump work
- Marshal the result back to the platform channel on the correct thread
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify native: `cd android && ./gradlew :app:testDebugUnitTest` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (native finding 10)
- Effort: S
- Where: `android/app/src/main/kotlin/com/bgdude/app/pump/PumpCommHandler.kt:114,199,294`
- Related: TASK-114, TASK-33
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
