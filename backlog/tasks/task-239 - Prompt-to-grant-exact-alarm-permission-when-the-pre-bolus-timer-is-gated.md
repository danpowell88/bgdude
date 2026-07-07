---
id: TASK-239
title: Prompt to grant exact-alarm permission when the pre-bolus timer is gated
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 12:49'
labels: []
milestone: m-8
dependencies: []
ordinal: 520000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-182 shipped the exact-alarm pre-bolus timer with a canScheduleExactNotifications() gate that silently falls back to an inexact alarm when the OS denies the permission. On Android 13 SCHEDULE_EXACT_ALARM is user-revocable and on Android 14+ it is denied by default, so for many users the pre-bolus timer will fire 30 to 40 minutes late in Doze with no way to fix it. There is no user-facing prompt or settings entry that requests the permission, unlike the battery-optimization exemption prompt added in TASK-183.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A Settings entry (and optionally an onboarding step) detects when exact alarms are unavailable and offers to open the system exact-alarm settings via the plugin requestExactAlarmsPermission() path
- [ ] #2 The prompt only appears when canScheduleExactNotifications() is false, and does not nag once addressed or dismissed
- [ ] #3 doc/user-guide.html documents the exact-alarm permission and why the pre-bolus timer needs it
- [ ] #4 Test asserts the prompt is shown only in the denied state
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: follow-up from TASK-182 completion review (2026-07-07)
- Sibling pattern: mirror the battery-optimization exemption prompt from TASK-183 (onboarding + Settings entry, state-tracked so it does not nag)
- The mode-selection and inexact fallback are already done in lib/insights/notifications.dart (preBolusScheduleMode / schedulePreBolusTimer); this ticket only adds the grant path
- flutter_local_notifications exposes requestExactAlarmsPermission() which opens the system settings screen
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [ ] #2 flutter analyze clean
- [ ] #3 flutter test test/ green
- [ ] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [ ] #8 backlog item updated with comments
<!-- DOD:END -->
