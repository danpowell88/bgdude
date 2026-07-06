---
id: TASK-176
title: 'Stale-data watchdog: alert when readings stop while connected'
status: To Do
assignee: []
created_date: '2026-07-06 09:17'
updated_date: '2026-07-06 12:57'
labels:
  - feature
  - alerts
  - "\U0001F512 safety"
milestone: m-3
dependencies: []
priority: high
ordinal: 101200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Alerts are driven solely by snapshot arrival (`lib/app.dart:28-31` → `AlertService.onSnapshot`), and `ConnectionAlertService` (`lib/state/providers.dart:1339-1367`) only arms its timer on disconnected/error stages — nothing tracks time-since-last-snapshot while the stage stays connected; native refresh is event-driven (`PumpCommHandler.kt:259-265`). Failure mode: sensor falls off at 2am with BLE still up → last reading treated as current forever, and no alert can ever fire.

**Value.** Closes the silent-stall gap: the user is told when data stops flowing even though the pump link looks healthy.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A periodic watchdog compares last-snapshot age to a threshold (~15-20 min) independent of connection stage
- [ ] #2 Firing produces a data-stale notification through the normal alert path (respecting the acute bypass rules)
- [ ] #3 Injected-clock unit test: no snapshot for N minutes → alert; recovery clears it
- [ ] #4 User guide alerting section updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a periodic watchdog (injected clock/timer) tracking last-snapshot age independent of connection stage.
- Route a data-stale alert through the normal alert path, respecting acute bypass rules; clear on recovery.
- Add injected-clock unit tests for fire and recovery.
- Update the alerting section of `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (reliability finding 2)
- Effort: M
- Where: `lib/state/providers.dart`, `lib/app.dart`, `doc/user-guide.html`
- Related: complements TASK-37 (process-death aliveness) — this is the in-process stall case
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
