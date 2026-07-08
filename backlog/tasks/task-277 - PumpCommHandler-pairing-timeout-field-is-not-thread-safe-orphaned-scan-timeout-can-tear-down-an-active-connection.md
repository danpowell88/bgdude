---
id: TASK-277
title: >-
  PumpCommHandler pairing-timeout field is not thread-safe -- orphaned scan
  timeout can tear down an active connection
status: Done
assignee:
  - Claude
created_date: '2026-07-07 23:27'
updated_date: '2026-07-08 02:07'
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
- [x] #1 pendingTimeout is @Volatile or both scheduleTimeout/cancelTimeout are guarded by a lock so a cross-thread cancel reliably removes the queued Runnable
- [x] #2 A cancel from the BLE-callback thread of a timeout scheduled on the executor thread always removes it (no orphaned Runnable)
- [x] #3 Test or reasoning demonstrates a connect during the scan-timeout window does not later trigger a spurious teardown
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-33)
- File: android/app/src/main/kotlin/com/bgdude/app/pump/PumpCommHandler.kt:126 (field), :128 scheduleTimeout, :135 cancelTimeout, :172 scan timeout, :304 submit cancel
- Same class as TASK-267 (Done) which volatilised bluetoothHandler/macFilter; this field was added by TASK-33 and missed
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 02:04
---
Started: making pendingTimeout @Volatile per AC #1, same fix class as TASK-267's sibling fields. Will add a Robolectric test pinning the cross-thread cancel race per AC #2/#3.
---

author: Claude
created: 2026-07-08 02:07
---
Fixed: pendingTimeout is now @Volatile (PumpCommHandler.kt:130), matching the sibling fields TASK-267 already volatilised -- a cancel on the BLE-callback/main-looper thread now reliably observes a schedule made on the pairing-executor thread instead of risking a stale null read.

AC#2/#3 (deterministic concurrency test): investigated writing a real multi-thread race test in the style of PumpCommHandlerConcurrencyTest, but concluded it can't cleanly isolate this specific bug -- every clean way to hand off between two JVM threads (Thread.start(), CountDownLatch.await/countDown, Handler.post) itself establishes a JMM happens-before edge, so a test built that way would pass whether or not the field were volatile, proving nothing. A genuinely unsynchronized visibility race is not deterministically reproducible in a JUnit test. Going with reasoning per AC#3's 'test or reasoning': the existing PairingWindowTimeoutTest suite already pins the functional cancel/schedule sequencing (e.g. 'submitting a code before the window expires cancels the timeout'); @Volatile is the established, minimal fix this codebase already uses for the identical cross-thread pattern on sibling fields (TASK-267), so it's applied for consistency and correctness rather than re-litigated with a bespoke test harness.

Verified: gradlew :app:testDebugUnitTest green (com.bgdude.app.pump.* suite), flutter analyze clean, flutter test --coverage green (1150 tests, 67.56% >= 65% floor), flutter build apk --debug succeeds. No Dart/user-guide changes needed (native-only, no user-visible surface).
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
