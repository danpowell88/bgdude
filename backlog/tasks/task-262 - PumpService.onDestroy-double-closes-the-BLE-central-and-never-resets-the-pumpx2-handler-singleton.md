---
id: TASK-262
title: >-
  PumpService.onDestroy double-closes the BLE central and never resets the
  pumpx2 handler singleton
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 17:29'
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
- [ ] #1 PumpCommHandler.stop() and PumpService.onDestroy are idempotent: a second stop/close does not throw (guard the unregister / catch IllegalArgumentException, or track closed state)
- [ ] #2 bluetoothHandler is nulled or the singleton is resetInstance()d on teardown so a sticky-restart re-establishes a live handler, not a stale one
- [ ] #3 Teardown always reaches GarminIntegration.shutdown() and super.onDestroy() even if BLE close throws
- [ ] #4 Robolectric test: stop() called twice (or unpair-then-destroy) does not throw
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-202), pumpx2/blessed internals verified via javap on the cached jars
- Files: android/app/src/main/kotlin/com/bgdude/app/pump/PumpService.kt onDestroy, PumpCommHandler.kt:122 stop() and :209 unpair()
- Charter-safe: neither stop() nor the Garmin shutdown issues a pump write
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
