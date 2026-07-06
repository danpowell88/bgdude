---
id: TASK-180
title: Guard notification init so a plugin failure cannot brick startup
status: To Do
assignee: []
created_date: '2026-07-06 09:18'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - alerts
milestone: m-8
dependencies: []
priority: medium
ordinal: 108100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/main.dart:46-49` awaits `notifications.init()`, `scheduleDailySummary()`, `scheduleWeeklyReport()` with no try/catch before `runApp` (only `registerBackgroundSummary` is guarded) — a plugin/channel init throw on an OEM ROM crash-loops the app: no UI, no alerts, no service.

**Reason for change.** Notification scheduling is a nice-to-have at startup; it must never prevent the app (and the safety-critical alert path) from booting.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each init/schedule call is individually guarded and logged; the app always reaches `runApp`
- [ ] #2 Test: an init that throws still boots the app shell
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Wrap `notifications.init()`, `scheduleDailySummary()` and `scheduleWeeklyReport()` in individual try/catch blocks with logging.
- Add a test injecting a throwing init and asserting the app shell still boots.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (reliability finding 6)
- Effort: S
- Where: `lib/main.dart`
- Related: TASK-38
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
