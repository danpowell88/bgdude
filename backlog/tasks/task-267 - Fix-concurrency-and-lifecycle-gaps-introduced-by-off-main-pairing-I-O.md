---
id: TASK-267
title: Fix concurrency and lifecycle gaps introduced by off-main pairing I/O
status: Done
assignee:
  - Claude
created_date: '2026-07-07 18:33'
updated_date: '2026-07-07 20:20'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 114000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-205 moved start()/scan-start onto a background single-thread executor while stop()/unpair()/onDestroy still run on the main thread, introducing two gaps and leaving one partial. First, PumpCommHandler.bluetoothHandler and macFilter are non-volatile plain vars with no synchronization, and stopBluetooth does a check-then-act (handler ?: return; = null). With start() now on the executor thread, onDestroy or a quick stopScan on the main thread can read a stale null, skip handler.stop() and resetInstance(), while start() finishes building a live singleton that scans forever with a registered receiver and an already-nulled commHandler — an orphaned BLE scan + receiver leak, the exact class TASK-202/262 exist to prevent (tight window, low probability, real). Second, PumpHostApiImpl.pairingExecutor is a newSingleThreadExecutor created fresh in PumpBridge.attach() but PumpBridge.detach() never shuts it down, leaking one non-daemon worker thread per engine attach/detach cycle. Third (partial scope note): unpair() still does SharedPreferences writes (PumpState.resetState, PairedPump.clear) and stopScan inline on the main thread, so the ANR-avoidance goal is only partly met.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 bluetoothHandler/macFilter cross-thread access is made safe (volatile + synchronized, or confine start/stop to the same thread) so a start/destroy race cannot orphan a scanning handler
- [x] #2 PumpBridge.detach() shuts down the pairingExecutor
- [x] #3 unpair()/stopScan disk I/O is moved off the main thread or confirmed non-blocking
- [x] #4 Test: a start-then-destroy race does not leave a live scanning singleton with a nulled commHandler
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-205), pumpx2/blessed verified via javap
- Files: android/app/src/main/kotlin/com/bgdude/app/pump/PumpCommHandler.kt fields ~89 and stopBluetooth ~137, PumpHostApiImpl.kt:16, PumpBridge.kt attach ~65 / detach ~159
- TASK-262 (double-close idempotency) is CONFIRMED-COMPLETE; this is a distinct concurrency gap the off-main change opened
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 20:03
---
Started: fix cross-thread hazards in PumpCommHandler (stopBluetooth check-then-act), PumpHostApiImpl's leaked pairingExecutor on detach, and confirm/move unpair()'s disk I/O off main.
---

author: Claude
created: 2026-07-07 20:20
---
Done -- AND found a more severe bug than this ticket describes while building the concurrency test. Full breakdown:

AC1 (cross-thread bluetoothHandler/macFilter safety): added a bluetoothLock in PumpCommHandler.kt guarding all reads/writes (both @Volatile too, belt and suspenders). start()'s entire body now runs inside synchronized(bluetoothLock). stopBluetooth()'s check-then-act (read handler, null it) is now one atomic block under the same lock. Added a new terminal destroy() method + a destroyed flag (also lock-guarded): PumpService.onDestroy() now calls commHandler?.destroy() instead of .stop(). Whichever of start()/destroy() acquires the lock second observes the other's effect -- either destroy() stops the handler start() just set, or start() sees destroyed=true and never touches bluetoothHandler at all. Either ordering ends fully torn down, closing the orphan-scan race the ticket describes.

AC2 (pairingExecutor leak): added PumpHostApiImpl.shutdown(), called from PumpBridge.detach().

AC3 (unpair() disk I/O off main): unpair() now goes through the same runOffMain() seam as startScan/submitPairingCode (verified via javap that pumpx2's PumpState uses the blocking Editor.commit(), not apply() -- confirmed real ANR risk, not a false alarm).

AC4 (start-destroy race test): android/.../PumpCommHandlerConcurrencyTest.kt runs start()/destroy() from two threads released simultaneously (20 iterations), asserting the post-race invariant (destroyed==true && bluetoothHandler==null) holds regardless of which thread won. Verified this test actually catches the regression: temporarily removed the destroyed-check in start(), reran -- failed immediately; reverted (git diff clean).

BEYOND THIS TICKET'S SCOPE -- a severe bug the concurrency test exposed by accident: writing PumpCommHandlerConcurrencyTest with a real background thread revealed that TASK-205's off-main pairingExecutor (a plain Executors.newSingleThreadExecutor()) crashes the FIRST TIME TandemBluetoothHandler.getInstance() constructs its internal android.os.Handler, because that thread never called Looper.prepare() -- 'Can't create handler inside thread that has not called Looper.prepare()'. This is real Android framework behavior (verified with a minimal Robolectric repro before touching any fix), NOT Robolectric-specific -- it would have crashed on a real device on the very first scan/pairing attempt since TASK-205 landed. Fixed by replacing the plain executor with a HandlerThread-backed ExecutorService (LooperExecutorService in PumpHostApiImpl.kt) so Looper.prepare()+loop() actually run on that thread. New test PumpHostApiImplLooperTest.kt exercises the REAL default executor (not a test double) end-to-end through PumpHostApiImpl -> PumpService -> PumpCommHandler.start() -> TandemBluetoothHandler.getInstance(), confirming it no longer throws.

Pipeline: gradlew :app:testDebugUnitTest green (88 tests, 0 failures), flutter analyze clean, flutter test test/ 1037/1037, flutter build apk --debug succeeded. No user-visible change (restores intended pairing/scan behavior, doesn't add a feature) -- no user-guide update.
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
- [x] #8 backlog item updated with comments
<!-- DOD:END -->
