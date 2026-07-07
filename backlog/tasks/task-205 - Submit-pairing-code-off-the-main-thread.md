---
id: TASK-205
title: Submit pairing code off the main thread
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:10'
updated_date: '2026-07-07 17:31'
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
- [x] #1 The pairing-code submit path moves off the main thread (existing executor/handler)
- [x] #2 The result is still marshalled back correctly
- [x] #3 `cd android && ./gradlew :app:testDebugUnitTest` green
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 17:24
---
Started: reviewing PumpCommHandler's pairing-code submit path and existing executor/handler patterns to move the disk I/O off the main thread.
---

author: Claude
created: 2026-07-07 17:31
---
Scope note: the ticket names 3 call sites. getPairingCodeCached() (PumpCommHandler.kt:301, onWaitingForPairingCode) is a pumpx2 BLE callback -- already invoked on pumpx2's own BLE callback thread, not the main/platform thread, so it wasn't actually a main-thread ANR risk; left untouched. The other two (PumpCommHandler.start()'s getJpakeDerivedSecretCached, and submitPairingCode()'s setPairingCode) ARE both genuinely reached synchronously from Flutter's MethodChannel dispatch (the main thread) via PumpHostApiImpl.startScan/submitPairingCode -- fixed both, matching the ticket's stated reason ('disk I/O on the main thread during pairing'), not just the title's literal 'submit pairing code' scope. No existing background-executor/coroutine pattern existed anywhere in this native codebase to reuse (kotlinx-coroutines is a transitive dependency but unused by our own code) -- added a plain injectable ExecutorService (defaults to Executors.newSingleThreadExecutor()) + a runOffMain(work, callback) helper on PumpHostApiImpl that runs work() on it and marshals the Result callback back onto the main Handler (Pigeon's Result callback must fire on the platform thread, same constraint PumpBridge's own EventChannel emit() helper already documents). Both executor and handler are constructor-injectable so tests don't need real Robolectric threading hacks beyond a real background thread + an explicit main-looper idle. Added android/.../PumpHostApiImplThreadingTest.kt: a RecordingExecutor wrapper captures which thread actually ran the work, proving it differs from the calling (test) thread for both submitPairingCode and startScan, and that the callback still marshals back successfully afterward. gradlew :app:testDebugUnitTest green (83 tests, 0 failures). flutter analyze clean, flutter test test/ green (983 tests), flutter build apk --debug succeeded. No user-visible/screen change -- DoD #6/#7 n/a.
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
