---
id: TASK-278
title: Bound the post-pairing-code bonding and authentication phase with a timeout
status: Done
assignee:
  - Claude
created_date: '2026-07-07 23:27'
updated_date: '2026-07-08 07:24'
labels: []
milestone: m-4
dependencies: []
priority: medium
ordinal: 515000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-33 bounded the scan wait and the pairing-code-entry wait with timeouts, but submitPairingCode (PumpCommHandler.kt:304) calls cancelTimeout() and schedules no replacement, relying on success, onInvalidPairingCode, or onPumpCriticalError always reaching a terminal state. If the pump goes silent after the code is submitted (BLE drop or out of range during JPAKE/bonding), none of those callbacks fire and no timeout is armed, so the connection hangs in bonding/jpakeInProgress forever with no user feedback -- the exact wait-forever state TASK-33 AC#5 aims to eliminate, just for the post-submit phase. The scan and code-entry waits are bounded; the bonding/authenticating wait is not.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A timeout covers submit-pairing-code through CONNECTED; if the pump goes silent during bonding/authentication the connection fails with a clear error rather than hanging
- [x] #2 The timeout tears down safely and idempotently (reuse the same safe stopBluetooth path) and emits an actionable message
- [x] #3 Test asserts the bonding-phase timeout fires and cleans up when no terminal callback arrives
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-33 AC#5)
- File: android/app/src/main/kotlin/com/bgdude/app/pump/PumpCommHandler.kt:304 submitPairingCode
- Related: TASK-277 (make the timeout field thread-safe first, since this adds another timeout on the same field)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 07:23
---
Started+fixed: added PairingWindowPolicy.BONDING_TIMEOUT_MS (60s) and scheduled it in both places that start a bonding/JPAKE handshake after cancelTimeout() with no replacement -- submitPairingCode (the ticket target) AND the auto-repair-with-saved-code branch in onWaitingForPairingCode (same structural gap, same fix, discovered while reading the surrounding code -- both drive the identical pair() handshake). onPumpConnected/onInvalidPairingCode/onPumpCriticalError already all call cancelTimeout() on their own terminal path, so no new wiring was needed there -- the new timeout is correctly disarmed by whichever one fires first. onBondingTimedOut() mirrors the existing onScanTimedOut/onPairingCodeTimedOut pattern: stopBluetooth() (the same safe, idempotent teardown every other timeout uses) + an actionable ERROR message. Updated the one existing test whose assumption my fix changes (submitting a code no longer leaves the connection un-timed-out -- that was the bug) and added 4 new tests: silent-pump-after-submit times out, CONNECTED cancels the new timeout, an invalid code cancels it, and the auto-repair path is bounded too. Rigor-checked both scheduleTimeout call sites independently (temp-commented each one, confirmed the matching new test failed with the predicted symptom, reverted, confirmed git diff --stat clean). Pipeline green: gradlew :app:testDebugUnitTest (7/7 in the affected file, full native suite green), flutter analyze clean, flutter build apk --debug succeeds. No Dart files touched, so flutter test/coverage unaffected by this change.
---

author: Claude
created: 2026-07-08 07:24
---
Done. AC#1/#2/#3 all delivered and verified (see prior comment for detail). DoD#1/#3/#4 not applicable -- no Dart source or generated files touched (native-only change), so build_runner/flutter test/coverage are unaffected; DoD#7/#8 not applicable -- no user-visible UI/screen/flow change (an internal safety-net timeout, same error-surfacing pattern as the existing scan/entry timeouts already documented in the user guide). Files: android/app/src/main/kotlin/com/bgdude/app/pump/PairingWindowPolicy.kt, PumpCommHandler.kt, android/app/src/test/kotlin/com/bgdude/app/pump/PairingWindowTimeoutTest.kt.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [ ] #3 flutter test --coverage test/ green
- [ ] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [x] #9 backlog item updated with comments
<!-- DOD:END -->
