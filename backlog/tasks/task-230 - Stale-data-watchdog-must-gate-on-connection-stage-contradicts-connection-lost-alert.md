---
id: TASK-230
title: >-
  Stale-data watchdog must gate on connection stage (contradicts connection-lost
  alert)
status: To Do
assignee: []
created_date: '2026-07-07 03:47'
labels:
  - code-health
  - alerts
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 113210
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The just-landed stale-data watchdog (`StaleDataWatchdogService._check`, `lib/state/providers.dart:1490-1504`, commit b8568bc / TASK-176) fires `dataStale` purely on snapshot age and never reads `pumpConnectionProvider`. On a genuine BLE disconnect the user gets two contradictory alerts: `connectionLost` at 10 min ("Pump disconnected — check Bluetooth") then `dataStale` at 15 min ("No new pump data ... even though the connection looks healthy") — the second is factually wrong and duplicative, and it is exactly the case the ticket said it was not meant to cover (its own class doc says "while the BLE link stays connected").

**Reason for change.** Contradictory alerts erode trust in the safety net; the watchdog must only own the connected-but-silent case, `ConnectionAlertService` (`providers.dart:1433-1461`) already owns the disconnect.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Watchdog bails (and resets its monitor) unless the live stage is connected
- [ ] #2 Unit test: disconnected + stale age fires no dataStale; connected + stale age still fires
- [ ] #3 Recovery/reset behaviour unchanged for the connected case
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Read the latest connection stage in `_check` (pattern at `app.dart:59`).
- Bail + reset when not connected; keep existing behaviour when connected.
- Extend `stale_data_watchdog_test.dart` with the disconnected case.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: hourly quality check 2026-07-07 (recent-landings review, finding 1)
- Effort: S
- Where: lib/state/providers.dart:1490-1504
- Related: TASK-176 (introduced), TASK-93
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
