---
id: TASK-227
title: Lower minSdk 29 -> 26 (document the floor rationale)
status: To Do
assignee: []
created_date: '2026-07-06 22:14'
labels:
  - native
  - infra
  - feature
milestone: m-7
dependencies:
  - TASK-226
priority: medium
ordinal: 505000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `build.gradle:39` minSdk 29 was hardcoded in the greenfield commit with no comment and nothing requires it: the audit found the binding floor is 26 (Health Connect client + notification channels); every other plugin floor is <=24; the untyped `startForeground` fallback already covers 26-28; and the manifest BLE model is already version-correct. With the BLE permission fix landed, 29 -> 26 costs essentially nothing and covers effectively all active Android devices.

**Value.** Broadest feasible device support, per the 2026-07-07 triage decision that some version-gated complexity is acceptable.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `minSdk = 26` with a comment naming the binding constraints
- [ ] #2 No new lint API-level violations (or each one gated)
- [ ] #3 App boots + demo mode verified on an API 26 emulator
- [ ] #4 SETUP.md floor updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Set `minSdk = 26` in `build.gradle:39` with a comment naming the binding constraints (Health Connect client, notification channels).
- Run lint and gate or fix any new API-level violations.
- Update the SETUP.md floor and rationale.
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify: `flutter build apk --debug` succeeds; boot an API 26 emulator and confirm the app starts and demo mode works.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: device-testing sweep 2026-07-07 (version audit)
- Effort: S
- Where: `android/app/build.gradle:39`, `SETUP.md`
- Related: TASK-217, TASK-223 (device-config matrix)
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
