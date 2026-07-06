---
id: TASK-182
title: Exact alarm for the pre-bolus timer
status: To Do
assignee: []
created_date: '2026-07-06 09:19'
labels:
  - code-health
  - alerts
milestone: m-8
dependencies: []
priority: medium
ordinal: 182000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** All scheduled notifications use `AndroidScheduleMode.inexactAllowWhileIdle` (`lib/insights/notifications.dart:109,131,148`) and the manifest declares no `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`; in Doze the 15-min pre-bolus timer (`lib/screens/meal_detail_screen.dart:250`) can fire 30-40 min late — the pre-bolus window is missed entirely. Daily/weekly summaries can stay inexact.

**Reason for change.** A pre-bolus timer that fires after the meal is useless; that one path needs exact-alarm semantics.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pre-bolus path uses `exactAllowWhileIdle` with the exact-alarm permission declared and `canScheduleExactAlarms()` gated (Android 14 fallback to inexact + note)
- [ ] #2 Test asserts the schedule mode per path (pre-bolus exact, summaries inexact)
- [ ] #3 User guide note added
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Declare the exact-alarm permission in the manifest and gate on `canScheduleExactAlarms()` with an Android 14 fallback to inexact plus a user-visible note.
- Switch only the pre-bolus schedule call to `exactAllowWhileIdle`; leave daily/weekly summaries inexact.
- Add a test asserting the schedule mode used per path.
- Update `doc/user-guide.html` with the exact-alarm note.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (reliability finding 8)
- Effort: S–M
- Where: `lib/insights/notifications.dart`, `lib/screens/meal_detail_screen.dart`, `android/app/src/main/AndroidManifest.xml`, `doc/user-guide.html`
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
