---
id: TASK-226
title: 'Fix BLE scanning below API 31: request ACCESS_FINE_LOCATION at runtime'
status: Blocked
assignee:
  - Claude
created_date: '2026-07-06 22:14'
updated_date: '2026-07-07 22:40'
labels:
  - code-health
  - pump
  - "\U0001F512 safety"
  - detail-needed
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
- [x] #1 An SDK-gated permission helper requests locationWhenInUse below API 31 and the split permissions at 31+
- [x] #2 Both onboarding paths and any re-pair flow use the helper
- [ ] #3 Tested on an API 29/30 emulator: scan starts after grant
- [x] #4 Denial is handled with a clear rationale message
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 19:38
---
Started: add an SDK-gated BLE permission helper (locationWhenInUse below API 31, split BT perms at 31+) and wire it into onboarding + re-pair.
---

author: Claude
created: 2026-07-07 19:46
---
detail-needed: AC#3 ('Tested on an API 29/30 emulator: scan starts after grant') cannot be verified in this session -- the only AVD available here is Pixel_7_Pro at android-37.0 (no API 29/30 image exists in this environment), and separately, the emulator VM-service WebSocket connection is broken here for ANY integration_test file regardless of API level (pre-existing, documented limitation). Needs a session with either a real API 29/30 device or a properly-provisioned API 29/30 AVD plus working emulator connectivity to close out -- matching the TASK-31/TASK-33/TASK-127 hardware/emulator-blocked convention rather than guessing it works.

AC#1/#2/#4 are done: lib/state/ble_permissions.dart (new) -- blePermissionRequirementFor(int sdkInt) is the pure SDK-gate decision (unit-tested directly, no mocking needed), requestBlePermissions() calls DeviceInfoPlugin().androidInfo.version.sdkInt then requests locationWhenInUse below API 31 or the split bluetoothConnect/bluetoothScan at 31+, blePermissionDeniedMessage() gives the matching rationale text. Wired into BOTH onboarding paths (_advance's background request, _startPairing's actual scan trigger with a SnackBar rationale on denial) and the settings screen's 're-pair pump' tile (previously called startScan() with NO permission request at all -- a revoked permission since onboarding would have silently failed to scan).

device_info_plus was already a transitive dependency (used by another plugin) -- promoted to direct in pubspec.yaml, no new native surface.

Tests: test/ble_permissions_test.dart pins the pure SDK-gate decision + rationale text for both branches.

Pipeline: flutter pub get, dart run build_runner build succeeded, flutter analyze clean (fixed a use_build_context_synchronously by capturing the ScaffoldMessenger before any await, matching the existing pattern elsewhere in this file), flutter test test/ 1034/1034, flutter build apk --debug succeeded. No native Kotlin touched. doc/user-guide.html: left unchanged -- this SnackBar-on-denial rationale matches the existing pattern for other permission prompts in the app (e.g. the glucose-meter screen's Bluetooth-off message), none of which get individual user-guide callouts.
---

author: Claude
created: 2026-07-07 22:40
---
Blocked: AC#3 requires an API 29/30 emulator image to confirm the runtime permission flow actually starts a scan after grant -- this session's only available AVD is Pixel_7_Pro at API 37, and there's no working emulator connectivity regardless (pre-existing limitation). AC#1/#2/#4 are done. Unblocked by: an API 29/30 AVD + working emulator connectivity.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
