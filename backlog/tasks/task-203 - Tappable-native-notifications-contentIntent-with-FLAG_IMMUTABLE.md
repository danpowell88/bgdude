---
id: TASK-203
title: Tappable native notifications (contentIntent with FLAG_IMMUTABLE)
status: To Do
assignee: []
created_date: '2026-07-06 21:10'
labels:
  - code-health
  - native
  - alerts
milestone: m-8
dependencies: []
priority: medium
ordinal: 111700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `PumpService.buildNotification` (`android/app/src/main/kotlin/com/bgdude/app/pump/PumpService.kt:153-160`) and the native urgent-low backstop notification (`PumpService.kt:198-205`) set no `contentIntent` — in the exact scenario the backstop exists for (Flutter UI dead, glucose below 55) tapping the alert does nothing.

- Verified: no other PendingIntents exist in the service/receiver code, so the added one must use `FLAG_IMMUTABLE` (API 31+)

**Reason for change.** Tapping an urgent-low backstop alert must open the app instead of doing nothing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Both notifications open MainActivity via an immutable PendingIntent
- [ ] #2 Test asserts contentIntent is present
- [ ] #3 `cd android && ./gradlew :app:testDebugUnitTest` green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Build a PendingIntent for MainActivity with `PendingIntent.FLAG_IMMUTABLE` (or immutable + update-current)
- Set it as `contentIntent` on both `buildNotification` and the urgent-low backstop notification
- Add a Robolectric test asserting contentIntent is present on both notifications
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify native: `cd android && ./gradlew :app:testDebugUnitTest` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (native finding 8)
- Effort: S
- Where: `android/app/src/main/kotlin/com/bgdude/app/pump/PumpService.kt:153-205`
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
