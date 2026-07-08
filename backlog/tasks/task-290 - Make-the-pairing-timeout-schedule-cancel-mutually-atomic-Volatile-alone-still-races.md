---
id: TASK-290
title: >-
  Make the pairing-timeout schedule/cancel mutually atomic -- @Volatile alone
  still races
status: To Do
assignee:
  - Claude
created_date: '2026-07-08 02:26'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 115000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The TASK-277 fix added @Volatile to pendingTimeout, which closes the visibility gap on the normal linear pairing path (calls are causally sequential across threads there). But @Volatile does not make the compound sequences atomic: scheduleTimeout does cancelTimeout(); pendingTimeout = r; postDelayed(r) and cancelTimeout does read; removeCallbacks; pendingTimeout = null. These run from three threads with NO shared lock covering them -- start()'s scheduleTimeout at :178 is inside synchronized(bluetoothLock), but stopBluetooth's cancelTimeout at :222 is OUTSIDE its lock block, and submitPairingCode (:310) and all the blessed BLE on* callbacks (onWaitingForPairingCode schedule :428 / cancel :411, onPumpConnected :441, onInvalidPairingCode :497, onPumpCriticalError :517) hold no lock. Reachable harmful interleaving (retry or sticky-restart/auto-reconnect): a fresh start() scheduleTimeout on the pairing executor/main thread runs concurrently with onWaitingForPairingCode scheduleTimeout on the BLE thread; both do field-set then postDelayed, so both Rscan and Rpair end up queued while pendingTimeout references only the last writer. The connection then succeeds, onPumpConnected cancels only the referenced Runnable, and the orphaned one fires later -> onPairingCodeTimedOut/onScanTimedOut -> stopBluetooth() tears down a now-live connected pump with a false timed-out error banner. No crash, but exactly the stale-timeout-tears-down-an-active-connection failure TASK-277 was filed to prevent -- just via a concurrent interleaving @Volatile cannot stop.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 scheduleTimeout and cancelTimeout are mutually atomic -- either @Synchronized on both (or a shared timeout lock around each body), or single-thread confinement by posting both bodies onto timeoutHandler (main looper)
- [ ] #2 No interleaving of a schedule and a cancel (or two schedules) from different threads can leave a Runnable queued while pendingTimeout does not reference it
- [ ] #3 Cancel remains synchronous where stopBluetooth relies on it (or ordering is otherwise preserved)
- [ ] #4 A concurrency test or documented reasoning shows the retry/reconnect interleaving no longer orphans a timeout
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 verifying the TASK-277 fix (09d4d10) -- @Volatile closed only the linear-path visibility half
- File: android/app/src/main/kotlin/com/bgdude/app/pump/PumpCommHandler.kt scheduleTimeout :134, cancelTimeout :141, and the unlocked call sites :222/:310/:411/:428/:441/:497/:517
- The benign timeout-fires-as-cancelled edge (main looper) needs no fix beyond onExpire idempotency, which stopBluetooth already has; optionally add a token guard if (pendingTimeout !== self) return
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [ ] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
