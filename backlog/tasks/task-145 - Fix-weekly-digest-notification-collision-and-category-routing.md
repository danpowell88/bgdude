---
id: TASK-145
title: Fix weekly-digest notification collision and category routing
status: To Do
assignee: []
created_date: '2026-07-06 08:41'
labels:
  - code-health
  - alerts
  - cleanup
milestone: m-8
dependencies: []
priority: medium
ordinal: 145000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `showWeeklyDigest` (`lib/insights/notifications.dart:92-94`) posts on the morningSummary channel with id 1002 while `scheduleWeeklyReport` (`:118-136`) schedules id 1002 on the reportDigest channel — one clobbers the other; digest content is gated on morningSummary prefs so the reportDigest category toggle does nothing for the actual digest.

**Reason for change.** Colliding ids make notifications silently replace each other, and the prefs toggle does not gate what it claims.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The digest is routed through `NotificationCategory.reportDigest`
- [ ] #2 It uses a distinct id (e.g. 1003)
- [ ] #3 A test asserts distinct ids across daily summary, weekly digest, weekly-report nudge
- [ ] #4 Prefs toggles gate what they claim
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Route `showWeeklyDigest` through `NotificationCategory.reportDigest` and give it a distinct id (e.g. 1003).
- Gate digest content on the reportDigest pref.
- Add a test asserting distinct ids across daily summary, weekly digest, weekly-report nudge.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/insights/notifications.dart:92-136`)
- Effort: S
- Where: `lib/insights/notifications.dart`
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
