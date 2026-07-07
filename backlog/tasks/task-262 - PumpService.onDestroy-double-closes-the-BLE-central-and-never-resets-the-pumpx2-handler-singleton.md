---
id: TASK-262
title: >-
  PumpService.onDestroy double-closes the BLE central and never resets the
  pumpx2 handler singleton
status: Done
assignee:
  - Claude
created_date: '2026-07-07 17:29'
updated_date: '2026-07-07 18:13'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 112000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The TASK-202 teardown is not idempotent. onDestroy calls commHandler.stop() which calls bluetoothHandler.stop() which (pumpx2) does central.stopScan() then central.close(); blessed close() calls context.unregisterReceiver(adapterStateReceiver) with no guard, and that receiver is registered only in the BluetoothCentralManager constructor (startScan never re-registers it). PumpCommHandler.stop() has no try/catch and does not null bluetoothHandler, and TandemBluetoothHandler is a process-wide static singleton that is never resetInstance()d. Reachable crash: unpair() (PumpCommHandler.kt:210) or a UI stopScan() closes the central once; when the service is later destroyed, onDestroy calls stop() again, the second central.close() throws IllegalArgumentException Receiver not registered, and it propagates as an uncaught native crash. It also short-circuits before GarminIntegration.shutdown() and super.onDestroy(), so the Garmin teardown this task added never runs on that path. Separately, because the singleton is never reset, a START_STICKY restart in a surviving process hands the new PumpCommHandler a stale handler whose central has the receiver unregistered and whose callbacks route to the dead listener, so the new service gets no snapshots. Adding central.close() in this commit is what turns the pre-existing stale-listener issue into a hard crash.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 PumpCommHandler.stop() and PumpService.onDestroy are idempotent: a second stop/close does not throw (guard the unregister / catch IllegalArgumentException, or track closed state)
- [x] #2 bluetoothHandler is nulled or the singleton is resetInstance()d on teardown so a sticky-restart re-establishes a live handler, not a stale one
- [x] #3 Teardown always reaches GarminIntegration.shutdown() and super.onDestroy() even if BLE close throws
- [x] #4 Robolectric test: stop() called twice (or unpair-then-destroy) does not throw
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-202), pumpx2/blessed internals verified via javap on the cached jars
- Files: android/app/src/main/kotlin/com/bgdude/app/pump/PumpService.kt onDestroy, PumpCommHandler.kt:122 stop() and :209 unpair()
- Charter-safe: neither stop() nor the Garmin shutdown issues a pump write
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 18:06
---
Started: investigating PumpCommHandler.stop()/PumpService.onDestroy idempotency per the review findings.
---

author: Claude
created: 2026-07-07 18:13
---
Done. Confirmed via javap (TandemBluetoothHandler.resetInstance() exists; blessed's BluetoothCentralManager.close()/stopScan() take no args) then reproduced the crash for real: wrote the 3 new Robolectric tests, stashed the fix, reran -- all 3 failed with the exact 'IllegalArgumentException: Receiver not registered' at PumpCommHandler.stop(), confirming the regression is real before restoring the fix.

Fix: PumpCommHandler.stop()/unpair() now route through a new private stopBluetooth() that (1) nulls bluetoothHandler before calling handler.stop() so a second call is a no-op -- AC#1, (2) catches IllegalArgumentException as defence in depth, and (3) calls TandemBluetoothHandler.resetInstance() so a later start() (sticky-restart reconnect) builds a fresh handler instead of reusing one with an unregistered receiver and dead-listener callbacks -- AC#2. PumpService.onDestroy() now wraps commHandler.stop() and GarminIntegration.shutdown() each in their own try/catch so both the Garmin teardown and super.onDestroy() always run even if BLE teardown throws -- AC#3.

Tests (AC#4): android/app/src/test/kotlin/.../PumpServiceDestroyTest.kt -- 'stopScan called twice after a real start does not throw', 'unpair followed by service onDestroy does not throw', 'onDestroy still reaches Garmin shutdown and super onDestroy after a double stop'. gradlew :app:testDebugUnitTest green (8 tests, PumpServiceDestroyTest + PumpCommHandlerReconnectTest). flutter analyze clean, flutter build apk --debug succeeded. No Dart changed -- no user-guide update (internal crash fix, no user-visible behavior change).
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
