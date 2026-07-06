---
id: TASK-224
title: Health Connect fake-data integration test (API 34 emulator)
status: To Do
assignee: []
created_date: '2026-07-06 22:14'
labels:
  - testing
milestone: m-8
dependencies:
  - TASK-219
priority: medium
ordinal: 113800
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Demo mode bypasses Health Connect with synthetic samples, so the REAL `health_sync.dart` path (isAvailable/requestAuthorization/getHealthDataFromTypes) has zero automated coverage. Health Connect is preinstalled on API 34+ emulator images and can be pre-seeded with fixed records via the HC test provider/adb.

**Reason for change.** The only untested half of the health pipeline is exactly the half that talks to the platform; a seeded API-34 emulator test closes that gap cheaply.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 On the API-34 config, Health Connect is seeded with fixed sleep/HRV/steps/HR records
- [ ] #2 Driving the sync surfaces the ingested `HealthSample`s in the sensitivity/correlation reads
- [ ] #3 The empty-HC fallback is asserted
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add CI steps that seed Health Connect on the API-34 emulator with fixed sleep/HRV/steps/HR records (HC test provider/adb).
- Add an integration test that runs the app in non-demo health mode, drives the sync, and asserts the ingested `HealthSample`s appear in the sensitivity/correlation reads.
- Add an empty-HC case asserting the fallback path.
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify: run the new test on an API-34 emulator (`flutter test integration_test/<file>.dart -d emulator-5554`).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: device-testing sweep 2026-07-07 (emulator audit)
- Effort: S
- Where: `health_sync.dart`, `integration_test/`, CI emulator workflow
- Related: TASK-92, TASK-118, TASK-207
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
