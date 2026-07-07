---
id: TASK-182
title: Exact alarm for the pre-bolus timer
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:19'
updated_date: '2026-07-07 10:43'
labels:
  - code-health
  - alerts
milestone: m-8
dependencies: []
priority: medium
ordinal: 108300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** All scheduled notifications use `AndroidScheduleMode.inexactAllowWhileIdle` (`lib/insights/notifications.dart:109,131,148`) and the manifest declares no `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`; in Doze the 15-min pre-bolus timer (`lib/screens/meal_detail_screen.dart:250`) can fire 30-40 min late — the pre-bolus window is missed entirely. Daily/weekly summaries can stay inexact.

**Reason for change.** A pre-bolus timer that fires after the meal is useless; that one path needs exact-alarm semantics.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Pre-bolus path uses `exactAllowWhileIdle` with the exact-alarm permission declared and `canScheduleExactAlarms()` gated (Android 14 fallback to inexact + note)
- [x] #2 Test asserts the schedule mode per path (pre-bolus exact, summaries inexact)
- [x] #3 User guide note added
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 08:00
---
Started: SCHEDULE_EXACT_ALARM in the manifest; pre-bolus uses exactAllowWhileIdle gated on canScheduleExactNotifications() with inexact fallback; mode-selection pure + tested; guide note.
---

author: Claude
created: 2026-07-07 10:43
---
Done: SCHEDULE_EXACT_ALARM declared in the manifest; NotificationService.schedulePreBolusTimer now checks canScheduleExactNotifications() and uses exactAllowWhileIdle when granted, inexactAllowWhileIdle otherwise (Android 14 default-deny fallback). Summaries/digests stay inexactAllowWhileIdle via the new summaryScheduleMode constant. Mode selection is a pure static fn (preBolusScheduleMode) so it's directly testable without a platform channel. Test: test/notification_schedule_test.dart 'schedule modes per path'. User guide updated (pre-bolus alert row notes the exact-alarm behavior). DoD #5/#7 N/A (no Kotlin change, no new screen). Pipeline green.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
