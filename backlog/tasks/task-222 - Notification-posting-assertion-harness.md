---
id: TASK-222
title: Notification-posting assertion harness
status: To Do
assignee: []
created_date: '2026-07-06 22:13'
labels:
  - testing
  - alerts
milestone: m-8
dependencies:
  - TASK-221
priority: medium
ordinal: 113600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** No test verifies an alert is actually POSTED to the OS — the biggest on-device coverage gap. `flutter_local_notifications ^17.2.2` exposes `getActiveNotifications()` and CI can also use `adb shell dumpsys notification`. Combined with scripted scenarios this makes alert flows true end-to-end (decided AND rendered), including quiet-hours suppression.

**Reason for change.** Alert delivery is safety-relevant; asserting only the in-app decision leaves the OS posting path (channels, permissions, suppression) untested.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A harness helper polls active notifications and asserts channel/title after a scenario
- [ ] #2 POST_NOTIFICATIONS is granted via adb in the CI job
- [ ] #3 Urgent-low and pump-alarm scenarios are asserted end-to-end
- [ ] #4 A quiet-hours suppression case is covered
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a harness helper that polls `getActiveNotifications()` and asserts channel/title with a timeout.
- Grant POST_NOTIFICATIONS via `adb shell pm grant` in the CI emulator job.
- Add end-to-end assertions for the urgent-low and pump-alarm scenarios.
- Add a quiet-hours case asserting the notification is suppressed.
- Verify: `flutter analyze` clean, `flutter test` green.
- Verify: run the notification tests on an emulator (`flutter test integration_test/<file>.dart -d emulator-5554`).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: device-testing sweep 2026-07-07 (emulator audit)
- Effort: S
- Where: `integration_test/harness.dart`, CI emulator workflow
- Related: TASK-93, TASK-144, TASK-203, TASK-211
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
