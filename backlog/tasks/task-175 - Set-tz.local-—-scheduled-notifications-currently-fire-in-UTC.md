---
id: TASK-175
title: Set tz.local — scheduled notifications currently fire in UTC
status: To Do
assignee: []
created_date: '2026-07-06 09:17'
labels:
  - code-health
  - alerts
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 175000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/main.dart:17` runs `tzdata.initializeTimeZones()` but nothing ever calls `tz.setLocalLocation(...)` (grep: zero usages), so `tz.TZDateTime(tz.local, ...)` in `lib/insights/notifications.dart:98-136` resolves wall-clock hours in UTC — in AEST (UTC+10) the 07:00 morning-summary nudge fires at 17:00 local, silently, every day.

**Reason for change.** Every wall-clock-scheduled notification is off by the UTC offset; the fix is one missing call in each isolate that schedules.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Device timezone resolved (e.g. `flutter_timezone`) and `tz.setLocalLocation` called in `main()` AND in the WorkManager isolate (`background_summary.dart:34`)
- [ ] #2 Unit test: `scheduleDailySummary` computes the expected absolute instant given a non-UTC local location
- [ ] #3 Manual check note recorded for DST transitions
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
