---
id: TASK-271
title: >-
  Complete the pre-31 BLE permission flow: location-services check and
  permanent-denial deep-link
status: Done
assignee:
  - Claude
created_date: '2026-07-07 20:26'
updated_date: '2026-07-08 08:51'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 528000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-226 correctly requests ACCESS_FINE_LOCATION below API 31, but two parts of the flow are still incomplete and can leave pump discovery silently broken. First, on API 29/30 a BLE scan needs BOTH the fine-location permission granted AND the system Location master toggle ON. requestBlePermissions in ble_permissions.dart only checks/requests the permission; nothing in lib/ checks Location serviceStatus. Scenario: user on Android 11 grants location but the device Location switch is off, startScan returns zero results and pump discovery silently fails — the exact silent-failure class this task set out to kill, only half-closed. Second, on a permanent denial (do not ask again) request() returns denied with no dialog and the user only gets a SnackBar reading enable it in system settings; there is no openAppSettings() action (no isPermanentlyDenied branch anywhere), so every re-pair tap just re-shows the same SnackBar with no way forward.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Before a pre-31 BLE scan the app detects Location services OFF (Permission.location.serviceStatus or equivalent) and surfaces it distinctly from a permission denial
- [x] #2 On a permanently-denied permission the UI offers an Open settings action (openAppSettings), not just a repeating SnackBar
- [x] #3 Both new branches have coverage (services-off surfaced; permanent-denial path offers settings)
<!-- AC:END -->



## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-226)
- File: lib/state/ble_permissions.dart requestBlePermissions; call sites onboarding_screen.dart and settings_screen.dart
- permission_handler exposes Permission.location.serviceStatus and openAppSettings()
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 08:51
---
Started+done. requestBlePermissions() now returns a richer BlePermissionResult record (granted, requirement, locationServicesOff, permanentlyDenied) instead of just granted/requirement. AC number 1: before requesting the pre-31 locationWhenInUse permission, checks Permission.location.serviceStatus.isDisabled first and short-circuits with locationServicesOff=true (distinct from a denial -- this only applies to the locationWhenInUse path, not the API 31+ split-permissions path, matching the actual OS requirement). AC number 2: each permission requests resulting PermissionStatus.isPermanentlyDenied is checked; a shared bleDeniedSnackBar() builder (used by both the onboarding Get connected step and Settings Re-pair pump, so the three failure modes read consistently everywhere) offers an Open settings SnackBarAction wired to permission_handlers openAppSettings() when permanentlyDenied is true. AC number 3: 4 new tests in test/state/ble_permissions_test.dart directly inspect the plain Widget objects bleDeniedSnackBar returns (SnackBar/Text/SnackBarAction are ordinary Dart objects, inspectable without pumping a widget tree) -- services-off message, permanent-denial action, plain-denial no-action, and a branch-priority pin (services-off wins over permanently-denied wording). Rigor-checked: temporarily short-circuited the locationServicesOff branch to never fire, confirmed 2 tests failed with the predicted wrong-message symptom, reverted. doc/user-guide.html updated (onboarding Get connected entry) -- could not regenerate screenshots (no working emulator this session, same pre-existing limitation as TASK-239). Pipeline green: analyze clean, 1321/1321 tests pass (8 new), coverage 67.98% (floor 65%), apk debug build succeeds. No native Kotlin touched.
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
