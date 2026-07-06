---
id: TASK-226
title: 'Fix BLE scanning below API 31: request ACCESS_FINE_LOCATION at runtime'
status: To Do
assignee: []
created_date: '2026-07-06 22:14'
labels:
  - code-health
  - pump
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 113250
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `onboarding_screen.dart:135,156-160` requests `bluetoothConnect`/`bluetoothScan`/`notification` unconditionally and NEVER requests `ACCESS_FINE_LOCATION` — on API 29/30 the split permissions do not exist (auto-granted no-ops) and a BLE scan legally requires fine location at runtime, so pump discovery is broken at the current minSdk today.

- The manifest is already correct: legacy perms carry `maxSdkVersion 30`, and `BLUETOOTH_SCAN` declares `neverForLocation`.

**Reason for change.** Pump discovery failing silently on API 29/30 devices is a safety-relevant onboarding blocker within the supported SDK range.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 An SDK-gated permission helper requests locationWhenInUse below API 31 and the split permissions at 31+
- [ ] #2 Both onboarding paths and any re-pair flow use the helper
- [ ] #3 Tested on an API 29/30 emulator: scan starts after grant
- [ ] #4 Denial is handled with a clear rationale message
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add an SDK-gated permission helper: locationWhenInUse below API 31, `bluetoothScan`/`bluetoothConnect` (+ notification) at 31+.
- Replace the unconditional requests in `onboarding_screen.dart` (both paths) and any re-pair flow with the helper.
- Add a denial rationale message with a path to settings.
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify: on an API 29/30 emulator, grant flow starts a scan; denial shows the rationale.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: device-testing sweep 2026-07-07 (version audit)
- Effort: S-M
- Where: `onboarding_screen.dart:135,156-160`, permission helper location TBD
- Related: TASK-12, TASK-33
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
