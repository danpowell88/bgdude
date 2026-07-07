---
id: TASK-176
title: 'Stale-data watchdog: alert when readings stop while connected'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:17'
updated_date: '2026-07-06 22:35'
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
- [x] #1 A periodic watchdog compares last-snapshot age to a threshold (~15-20 min) independent of connection stage
- [x] #2 Firing produces a data-stale notification through the normal alert path (respecting the acute bypass rules)
- [x] #3 Injected-clock unit test: no snapshot for N minutes → alert; recovery clears it
- [x] #4 User guide alerting section updated
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 22:30
---
Started: pure StaleDataMonitor (injected times) + periodic provider service; new dataStale notification category routed through NotificationService.show (normal enabled/quiet-hours path, reviewed as a quiet-hours exclusion since the pump's own alarms remain the overnight primary); guide alert table updated.
---

author: Claude
created: 2026-07-06 22:35
---
Done (commit b8568bc).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Pure StaleDataMonitor (lib/insights/stale_data_watchdog.dart): 15-min threshold on last-snapshot age independent of connection stage, one becameStale event per episode, recovered on the next snapshot. StaleDataWatchdogService (providers.dart) runs a 5-min periodic check and fires the new high-importance dataStale category through NotificationService.show (normal enabled/quiet-hours path). dataStale added as a reviewed quiet-hours exclusion (pump/CGM alarms remain the primary overnight net) — guard test updated. app.dart feeds the watchdog each snapshot. 6 injected-clock tests cover never-stale-before-data, quiet-while-flowing, fire-once, recovery, re-stall re-fire. Guide alert table row added. Verified: analyze clean, 645 tests green, debug APK builds. Commit b8568bc.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
