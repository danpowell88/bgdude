---
id: TASK-271
title: >-
  Complete the pre-31 BLE permission flow: location-services check and
  permanent-denial deep-link
status: To Do
assignee:
  - Claude
created_date: '2026-07-07 20:26'
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
- [ ] #1 Before a pre-31 BLE scan the app detects Location services OFF (Permission.location.serviceStatus or equivalent) and surfaces it distinctly from a permission denial
- [ ] #2 On a permanently-denied permission the UI offers an Open settings action (openAppSettings), not just a repeating SnackBar
- [ ] #3 Both new branches have coverage (services-off surfaced; permanent-denial path offers settings)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: recent-code review 2026-07-08 (follow-up to TASK-226)
- File: lib/state/ble_permissions.dart requestBlePermissions; call sites onboarding_screen.dart and settings_screen.dart
- permission_handler exposes Permission.location.serviceStatus and openAppSettings()
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
