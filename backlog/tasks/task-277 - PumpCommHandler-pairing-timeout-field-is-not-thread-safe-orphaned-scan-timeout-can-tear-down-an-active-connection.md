---
id: TASK-277
title: >-
  PumpCommHandler pairing-timeout field is not thread-safe -- orphaned scan
  timeout can tear down an active connection
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 23:27'
labels: []
milestone: m-8
dependencies: []
priority: high
ordinal: 113000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The pairing-window timeout added in TASK-33 stores its pending Runnable in a plain private var pendingTimeout (PumpCommHandler.kt:126) read and written from three threads with no @Volatile or lock: start() runs on the pairing executor (per the off-main change TASK-267 addressed), the blessed BLE callbacks (onWaitingForPairingCode, onPumpConnected) run on the callback thread, and the expiry Runnable runs on the main looper. The Handler itself is main-looper-bound and thread-safe, but the field is not, and a comment at line 122 even acknowledges the cross-thread concern while leaving the field unguarded -- the sibling fields at :76/:101/:105/:110 were made @Volatile by TASK-267, this one (added later by TASK-33) was missed. Concrete failure: start() schedules the scan timeout (pendingTimeout = scanRunnable); onWaitingForPairingCode calls cancelTimeout() but with no happens-before may read a stale null, so removeCallbacks(scanRunnable) never runs and the scan Runnable stays queued; it then overwrites pendingTimeout with the pairing Runnable; onPumpConnected cancels only the pairing Runnable. About 2 minutes after start the orphaned scan Runnable fires on the main looper -> onScanTimedOut -> stopBluetooth() tears down a now-CONNECTED pump and emits ERROR No pump found nearby. stopBluetooth is idempotent so no crash -- just a spurious teardown of a working connection plus a misleading error.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 pendingTimeout is @Volatile or both scheduleTimeout/cancelTimeout are guarded by a lock so a cross-thread cancel reliably removes the queued Runnable
- [ ] #2 A cancel from the BLE-callback thread of a timeout scheduled on the executor thread always removes it (no orphaned Runnable)
- [ ] #3 Test or reasoning demonstrates a connect during the scan-timeout window does not later trigger a spurious teardown
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-33)
- File: android/app/src/main/kotlin/com/bgdude/app/pump/PumpCommHandler.kt:126 (field), :128 scheduleTimeout, :135 cancelTimeout, :172 scan timeout, :304 submit cancel
- Same class as TASK-267 (Done) which volatilised bluetoothHandler/macFilter; this field was added by TASK-33 and missed
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
