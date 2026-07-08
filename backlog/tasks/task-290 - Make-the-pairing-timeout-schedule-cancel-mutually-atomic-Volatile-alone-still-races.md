---
id: TASK-290
title: >-
  Make the pairing-timeout schedule/cancel mutually atomic -- @Volatile alone
  still races
status: Done
assignee:
  - Claude
created_date: '2026-07-08 02:26'
updated_date: '2026-07-08 02:46'
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
- [x] #1 scheduleTimeout and cancelTimeout are mutually atomic -- either @Synchronized on both (or a shared timeout lock around each body), or single-thread confinement by posting both bodies onto timeoutHandler (main looper)
- [x] #2 No interleaving of a schedule and a cancel (or two schedules) from different threads can leave a Runnable queued while pendingTimeout does not reference it
- [x] #3 Cancel remains synchronous where stopBluetooth relies on it (or ordering is otherwise preserved)
- [x] #4 A concurrency test or documented reasoning shows the retry/reconnect interleaving no longer orphans a timeout
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 verifying the TASK-277 fix (09d4d10) -- @Volatile closed only the linear-path visibility half
- File: android/app/src/main/kotlin/com/bgdude/app/pump/PumpCommHandler.kt scheduleTimeout :134, cancelTimeout :141, and the unlocked call sites :222/:310/:411/:428/:441/:497/:517
- The benign timeout-fires-as-cancelled edge (main looper) needs no fix beyond onExpire idempotency, which stopBluetooth already has; optionally add a token guard if (pendingTimeout !== self) return
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 02:40
---
Started: adding a dedicated timeoutLock and synchronizing scheduleTimeout/cancelTimeout's bodies on it, matching the bluetoothLock/snapshotLock pattern already used in this file for the same class of cross-thread field problem.
---

author: Claude
created: 2026-07-08 02:46
---
Fixed: added a dedicated timeoutLock and made scheduleTimeout/cancelTimeout's ENTIRE bodies synchronized on it (not just the field access) -- matches the option AC#1 suggested ('a shared timeout lock around each body'). Every call site (start's scheduleTimeout inside bluetoothLock, stopBluetooth/submitPairingCode/the on* BLE callbacks' cancelTimeout with no lock at all) now funnels through the same mutex regardless of what outer lock (if any) the caller holds, so the read-modify-write sequence is atomic system-wide -- no code change needed at any call site. Removed the now-redundant @Volatile (synchronized already establishes the happens-before TASK-277 needed it for). cancelTimeout stays a plain synchronous function, so stopBluetooth's ordering is unchanged (AC#3).

AC#4: added android/app/src/test/kotlin/com/bgdude/app/pump/PairingTimeoutConcurrencyTest.kt with two stress tests (300 repeats each, real threads released simultaneously via CountDownLatch, matching PumpCommHandlerConcurrencyTest's established pattern for this class of bug): (1) two concurrent onWaitingForPairingCode calls (order-independent -- same duration/callback either way) must fire at most one timeout, never two; (2) start() racing onWaitingForPairingCode -- the exact unlocked gap the finding named -- must not orphan the scan timeout within its window.

Rigor check: reverted to the old unsynchronized bodies, reran -- at repeat(20) it did NOT reliably reproduce (data races are probabilistic; Android's MessageQueue is itself internally thread-safe, so only the Kotlin-level pendingTimeout sequencing races), but bumping to repeat(300) caught it (test 1 failed with a genuine double-fire). Kept repeat(300) in the committed test for real detection power at negligible cost (~13s for the whole file). Reverted the bug; git diff on the production file is a clean, intentional change.

Verified: flutter analyze clean, gradlew :app:testDebugUnitTest green (full suite, not just the new file), flutter build apk --debug succeeds. No Dart changed, so flutter test/coverage unaffected by this native-only fix (unchanged from the last full run).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [x] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
