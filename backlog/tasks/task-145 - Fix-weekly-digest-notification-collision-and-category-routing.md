---
id: TASK-145
title: Fix weekly-digest notification collision and category routing
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:41'
updated_date: '2026-07-07 04:20'
labels:
  - code-health
  - alerts
  - cleanup
milestone: m-8
dependencies: []
priority: medium
ordinal: 106800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `showWeeklyDigest` (`lib/insights/notifications.dart:92-94`) posts on the morningSummary channel with id 1002 while `scheduleWeeklyReport` (`:118-136`) schedules id 1002 on the reportDigest channel — one clobbers the other; digest content is gated on morningSummary prefs so the reportDigest category toggle does nothing for the actual digest.

**Reason for change.** Colliding ids make notifications silently replace each other, and the prefs toggle does not gate what it claims.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The digest is routed through `NotificationCategory.reportDigest`
- [x] #2 It uses a distinct id (e.g. 1003)
- [x] #3 A test asserts distinct ids across daily summary, weekly digest, weekly-report nudge
- [x] #4 Prefs toggles gate what they claim
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 04:17
---
Started: route the weekly digest through reportDigest with a distinct id 1003; add id-uniqueness test; prefs then gate what they claim (show() already gates by category).
---

author: Claude
created: 2026-07-07 04:20
---
Done.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
showWeeklyDigest routes through NotificationCategory.reportDigest with distinct id 1003 (weeklyDigestId); ids for daily summary (1000), morning summary (1001), weekly-report nudge (1002) and digest (1003) are named constants with a uniqueness test. Prefs now gate what they claim: show() gates by the routed category, so the reportDigest toggle controls both the nudge and the digest, and morningSummary controls only the summaries. Verified: analyze clean, 721 tests green, APK builds.
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
