---
id: TASK-265
title: >-
  System-health rows should go stale when last-success exceeds a subsystems
  expected cadence
status: Done
assignee:
  - Claude
created_date: '2026-07-07 17:30'
updated_date: '2026-07-08 09:31'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 530000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
SubsystemHealth.isUnhealthy is consecutiveFailures > 0 OR (attempted AND never succeeded). There is no time-since-last-success threshold anywhere. Failure scenario: a WorkManager or periodic job (health sync, reconciliation) stops being scheduled after an OS kill or a cancelled job — it neither succeeds nor throws, so nothing is recorded and the row shows a green check with Last success 6d ago indefinitely. Silent cessation is the most common and most dangerous background-failure mode and is exactly what a health screen exists to catch, yet it is invisible. The user guide currently only promises red-on-failure (which is accurate to the code), so this is an enhancement to detect silent stalls, not a doc mismatch.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Each subsystem has an expected cadence and its row goes stale/amber when last-success exceeds it, even with zero recorded failures
- [x] #2 The cadence thresholds match each subsystems real schedule (not a single global value)
- [x] #3 User guide updated to describe the stale/amber state
- [x] #4 Test: a subsystem with an old last-success and no recent attempt reads stale, not healthy
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-201)
- File: lib/insights/system_health.dart:60 isUnhealthy
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 09:19
---
Started. Investigated the real trigger for each subsystem before picking thresholds (there is no single global WorkManager job -- background_summary.dart is the only registerPeriodicTask call and it drives an unrelated feature): healthSync/predictionReconciliation run via AppJobs.runStartup() on every app cold-start + resume (main_shell.dart), no fixed clock interval; forecasterTraining is additionally throttled to a real ~20h internal gate (_forecasterTrainingDue); garminDelivery is CGM-push-triggered (~5 min, native, MIN_SEND_INTERVAL_MS=60s is just a debounce floor not the real cadence) and reported via a SEPARATE platform-channel path (garminHealthProvider/_GarminTile), not through SystemHealthReport at all -- its enum entry in the main report is always empty by design; weather has genuinely NO periodic refresh anywhere in the codebase (fetches once per app-process lifetime + on user city-edit only) -- no real cadence exists to derive a threshold from; modelDownload is one-shot, user-tap-triggered, not a recurring job at all. Plan: expectedCadence returns null (excluded from staleness, with each case commented on the real reason) for weather/modelDownload/garminDelivery-via-SystemHealthReport (dead path); 48h for healthSync/predictionReconciliation/forecasterTraining (generous vs their app-open-driven, ~20h-throttled reality); Garmin gets its OWN staleness check directly in _GarminTile (its real ~5min cadence, generous ~15min threshold) since it is a real, separately-reported subsystem the AC still names. Adding a third stale/amber UI state distinct from the existing red-unhealthy/green-healthy, matching the warning_amber pattern already used in insights_screen.dart/main_shell.dart.
---

author: Claude
created: 2026-07-08 09:31
---
Done. AC number 1/2: Subsystem.expectedCadence (48h for healthSync/predictionReconciliation/forecasterTraining -- their real app-open/resume-driven, ~20h-internally-throttled reality with generous headroom; null for garminDelivery/weather/modelDownload with each cases comment explaining exactly why no real cadence exists to derive a number from, rather than guessing). SubsystemHealth.isStale(now, cadence) fires only when NOT already unhealthy (a real recorded failure is worse than merely stale and must win display-wise), cadence is non-null, and a past success exists but is older than that cadence. Garmin gets its own client-side staleness check directly in _GarminTile (its real ~5min CGM-push cadence, ~15min generous threshold) since it is reported via a separate native platform-channel path, not through SystemHealthReport at all. AC number 3: user guide System health entry now describes red/amber/green with the concrete thresholds and explains why weather/model-download never go amber. AC number 4: 5 unit tests in system_health_test.dart pin isStale directly (old success -> stale despite zero failures; recent success -> not stale; null cadence -> never stale; never-succeeded -> not stale, thats isUnhealthy; a real failure takes priority over staleness) plus 4 widget tests in a new test/ui/system_health_screen_test.dart exercising the actual icon/colour selection in _SubsystemTile (not just the underlying data logic). Rigor-checked three separate things: the core isStale null-cadence guard (removed it, confirmed the predicted test failed), the UI icon-selection branch (dropped the stale case, confirmed the predicted widget test failed) -- both reverted cleanly. Pipeline green: analyze clean, 1334/1334 tests pass (9 new), coverage 68.60% (floor 65%), apk debug build succeeds. No native Kotlin touched. Could not regenerate screenshots (no working emulator this session, same pre-existing limitation noted on TASK-239/271).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [x] #7 Integration test added or extended when a screen/flow changed
- [x] #8 backlog item updated with comments
<!-- DOD:END -->
