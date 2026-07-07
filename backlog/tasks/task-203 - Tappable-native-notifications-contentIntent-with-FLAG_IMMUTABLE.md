---
id: TASK-203
title: Tappable native notifications (contentIntent with FLAG_IMMUTABLE)
status: Done
assignee:
  - Claude
created_date: '2026-07-06 21:10'
updated_date: '2026-07-07 17:14'
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
- [x] #1 Both notifications open MainActivity via an immutable PendingIntent
- [x] #2 Test asserts contentIntent is present
- [x] #3 `cd android && ./gradlew :app:testDebugUnitTest` green
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 17:08
---
Started: adding a contentIntent (immutable PendingIntent to MainActivity) to both PumpService notifications.
---

author: Claude
created: 2026-07-07 17:14
---
Added mainActivityContentIntent() (an immutable PendingIntent to MainActivity with FLAG_ACTIVITY_NEW_TASK|CLEAR_TOP) and wired it as .setContentIntent(...) on both buildNotification (the ongoing connection notification) and the urgent-low backstop notification -- both now use the same shared request code (deliberate: same intent, so FLAG_UPDATE_CURRENT just refreshes one PendingIntent rather than creating two). Added android/.../PumpServiceNotificationIntentTest.kt (2 Robolectric tests): one grants BLUETOOTH_CONNECT + drives the real onCreate/onStartCommand path and asserts shadowOf(service).lastForegroundNotification.contentIntent is non-null; the other calls the real (public, interface-required) onSnapshotUpdated with a simulated 40 mg/dL reading, confirms the urgent-low notification (id 43) actually posts via ShadowNotificationManager, and asserts its contentIntent is non-null too. gradlew :app:testDebugUnitTest green (81 tests, 0 failures). flutter analyze clean, flutter test test/ green (978 tests), flutter build apk --debug succeeded. No user-visible/screen change beyond the notification now being tappable -- DoD #6/#7 n/a.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
