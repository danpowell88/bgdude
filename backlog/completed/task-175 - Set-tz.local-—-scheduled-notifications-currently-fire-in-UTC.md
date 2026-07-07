---
id: TASK-175
title: Set tz.local — scheduled notifications currently fire in UTC
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:17'
updated_date: '2026-07-06 22:35'
labels:
  - code-health
  - alerts
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 101100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/main.dart:17` runs `tzdata.initializeTimeZones()` but nothing ever calls `tz.setLocalLocation(...)` (grep: zero usages), so `tz.TZDateTime(tz.local, ...)` in `lib/insights/notifications.dart:98-136` resolves wall-clock hours in UTC — in AEST (UTC+10) the 07:00 morning-summary nudge fires at 17:00 local, silently, every day.

**Reason for change.** Every wall-clock-scheduled notification is off by the UTC offset; the fix is one missing call in each isolate that schedules.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Device timezone resolved (e.g. `flutter_timezone`) and `tz.setLocalLocation` called in `main()` AND in the WorkManager isolate (`background_summary.dart:34`)
- [x] #2 Unit test: `scheduleDailySummary` computes the expected absolute instant given a non-UTC local location
- [x] #3 Manual check note recorded for DST transitions
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a timezone-resolution dependency (e.g. `flutter_timezone`) and call `tz.setLocalLocation` in `main()` before scheduling.
- Do the same in the WorkManager isolate entrypoint (`lib/insights/background_summary.dart:34`).
- Add a unit test asserting `scheduleDailySummary` yields the expected absolute instant under a non-UTC location.
- Record a manual-check note covering DST transitions.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (reliability finding 1)
- Effort: S
- Where: `lib/main.dart`, `lib/insights/notifications.dart`, `lib/insights/background_summary.dart`
- Related: TASK-131 covers ML features; this is the notification surface
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 22:21
---
Started: resolve the device timezone (flutter_timezone) and setLocalLocation in main() and the WorkManager isolate; unit-test scheduleDailySummary under a non-UTC location; record the DST manual-check note.
---

author: Claude
created: 2026-07-06 22:35
---
Done (in commit b8568bc push). DST manual-check note: verify the 07:00 summary on the device across the 2026-10-04 Sydney spring-forward; unit tests cover both transitions already.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
configureLocalTimezone() (lib/core/local_timezone.dart, flutter_timezone 5.x -> tz.setLocalLocation) called in main() and in the WorkManager isolate after initializeTimeZones. Schedule computation extracted to pure NotificationService.nextDailyInstant/nextWeeklyInstant and made DST-safe (day+1 construction, not +24h). Sydney tests pin 07:00 AEST = 21:00 UTC, spring-forward (20:00 UTC) and fall-back (21:00 UTC) transitions, and weekly rollover. Manual DST check note: on the next real transition (Sydney 2026-10-04), confirm the morning summary still arrives at 07:00 local — the plugin's matchDateTimeComponents:time recomputes subsequent repeats, so only the first instant was at risk. Verified: build_runner, analyze clean, 645 tests green, debug APK builds with the new plugin.
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
