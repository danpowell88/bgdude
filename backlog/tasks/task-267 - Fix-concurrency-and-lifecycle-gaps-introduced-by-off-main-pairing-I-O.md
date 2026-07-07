---
id: TASK-267
title: Fix concurrency and lifecycle gaps introduced by off-main pairing I/O
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 18:33'
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
- [ ] #1 bluetoothHandler/macFilter cross-thread access is made safe (volatile + synchronized, or confine start/stop to the same thread) so a start/destroy race cannot orphan a scanning handler
- [ ] #2 PumpBridge.detach() shuts down the pairingExecutor
- [ ] #3 unpair()/stopScan disk I/O is moved off the main thread or confirmed non-blocking
- [ ] #4 Test: a start-then-destroy race does not leave a live scanning singleton with a nulled commHandler
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-205), pumpx2/blessed verified via javap
- Files: android/app/src/main/kotlin/com/bgdude/app/pump/PumpCommHandler.kt fields ~89 and stopBluetooth ~137, PumpHostApiImpl.kt:16, PumpBridge.kt attach ~65 / detach ~159
- TASK-262 (double-close idempotency) is CONFIRMED-COMPLETE; this is a distinct concurrency gap the off-main change opened
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
