---
id: TASK-239
title: Prompt to grant exact-alarm permission when the pre-bolus timer is gated
status: Done
assignee:
  - Claude
created_date: '2026-07-07 12:49'
updated_date: '2026-07-08 08:02'
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
- [x] #1 A Settings entry (and optionally an onboarding step) detects when exact alarms are unavailable and offers to open the system exact-alarm settings via the plugin requestExactAlarmsPermission() path
- [x] #2 The prompt only appears when canScheduleExactNotifications() is false, and does not nag once addressed or dismissed
- [x] #3 doc/user-guide.html documents the exact-alarm permission and why the pre-bolus timer needs it
- [x] #4 Test asserts the prompt is shown only in the denied state
<!-- AC:END -->



## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: follow-up from TASK-182 completion review (2026-07-07)
- Sibling pattern: mirror the battery-optimization exemption prompt from TASK-183 (onboarding + Settings entry, state-tracked so it does not nag)
- The mode-selection and inexact fallback are already done in lib/insights/notifications.dart (preBolusScheduleMode / schedulePreBolusTimer); this ticket only adds the grant path
- flutter_local_notifications exposes requestExactAlarmsPermission() which opens the system settings screen
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 08:02
---
Started+done. Mirrored TASK-183s battery-optimization tile pattern: added NotificationService.canScheduleExactAlarms()/requestExactAlarmPermission() wrapping the plugin (canScheduleExactNotifications/requestExactAlarmsPermission, the same check schedulePreBolusTimer already gates on), and a new _ExactAlarmExemptionTile in settings_screen.dart -- shows only when denied, hides entirely once granted (no nagging), re-checks after the user returns from Androids exact-alarm settings screen since the OS gives no grant/deny callback. Skipped the onboarding-step half of AC number 1 (the AC itself says "optionally") -- unlike battery optimization (a quick system dialog), the exact-alarm grant navigates the user to a full system settings SCREEN, which is a much bigger interruption to drop into the middle of the onboarding flow; the Settings-screen entry is the persistent, always-reachable path and is the ACs primary ask. Added test/ui/settings_screen_exact_alarm_test.dart (3 tests: shown when denied, hidden when granted, tap requests + hides). Rigor-checked: temporarily broke the hide-when-granted condition, confirmed 2 of the 3 new tests failed with the predicted symptom, reverted. Real regression caught by the full suite run (not the rigor check): notificationServiceProvider throws UnimplementedError by default outside main(), and the new tile now touches it from SettingsScreen -- settings_screen_health_sync_test.dart renders SettingsScreen without overriding that provider, so it broke; fixed by adding a minimal _FakeNotificationService override there. doc/user-guide.html updated with the new Settings row. Could NOT regenerate screenshots (no working emulator in this session, confirmed pre-existing limitation) -- the row is text-described only, matching how the equivalent battery-optimization row is documented (no dedicated screenshot for that row either, so this is consistent with the existing guide, not a new gap). Pipeline green: analyze clean, 1317/1317 tests pass (3 new), coverage 67.95% (was 67.94%, floor 65%), apk debug build succeeds. No native Kotlin touched.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #7 Integration test added or extended when a screen/flow changed
- [x] #8 backlog item updated with comments
<!-- DOD:END -->
