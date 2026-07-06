---
id: TASK-183
title: Battery-optimization exemption prompt in onboarding
status: To Do
assignee: []
created_date: '2026-07-06 09:19'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - onboarding
milestone: m-7
dependencies: []
priority: medium
ordinal: 108400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Grep shows no `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` / `isIgnoringBatteryOptimizations` anywhere and onboarding never asks — App Standby/Doze throttles BLE callback delivery and defers the WorkManager summary backstop indefinitely on a phone left idle for days.

**Reason for change.** A continuous-monitoring app that never requests the exemption will be throttled by every stock battery manager; users should be asked once, with a clear rationale.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Onboarding (and a Settings entry) requests the exemption with a plain-language rationale
- [ ] #2 State reflected so the prompt does not nag
- [ ] #3 User guide updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add the `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` manifest entry and a platform-channel or plugin check for `isIgnoringBatteryOptimizations`.
- Add an onboarding step and a Settings entry with a plain-language rationale; persist the answered state so it does not nag.
- Update `doc/user-guide.html` (onboarding + settings sections).
- Add/extend an integration test for the new onboarding step in demo mode.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (reliability finding 9)
- Effort: S
- Where: onboarding screens, settings screen, `android/app/src/main/AndroidManifest.xml`, `doc/user-guide.html`
- Related: TASK-95, TASK-96 — coordinate
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
