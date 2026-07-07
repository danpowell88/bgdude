---
id: TASK-278
title: Bound the post-pairing-code bonding and authentication phase with a timeout
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 23:27'
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
- [ ] #1 A timeout covers submit-pairing-code through CONNECTED; if the pump goes silent during bonding/authentication the connection fails with a clear error rather than hanging
- [ ] #2 The timeout tears down safely and idempotently (reuse the same safe stopBluetooth path) and emits an actionable message
- [ ] #3 Test asserts the bonding-phase timeout fires and cleans up when no terminal callback arrives
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-33 AC#5)
- File: android/app/src/main/kotlin/com/bgdude/app/pump/PumpCommHandler.kt:304 submitPairingCode
- Related: TASK-277 (make the timeout field thread-safe first, since this adds another timeout on the same field)
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
