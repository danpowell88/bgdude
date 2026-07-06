---
id: TASK-209
title: mounted guards on meter-screen async callbacks
status: To Do
assignee: []
created_date: '2026-07-06 21:11'
labels:
  - code-health
  - ui
milestone: m-8
dependencies: []
priority: medium
ordinal: 112300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/glucose_meter_screen.dart:40` calls setState after `await transport.isAvailable()` without a mounted check, and the scan-result listener at `lib/glucose_meter_screen.dart:46` mutates state in onData unguarded (unlike lines 50/53 which do guard).

**Reason for change.** Leaving the screen mid-scan throws setState-after-dispose.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 mounted guards added to both call sites
- [ ] #2 Widget test: dispose mid-scan, deliver a result, no error
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a mounted check after `await transport.isAvailable()` before setState
- Guard the scan-result onData listener the same way lines 50/53 already do
- Add a widget test that disposes the screen mid-scan, delivers a result, and asserts no error
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep rerun 2026-07-07 (dart finding 14)
- Effort: S
- Where: `lib/glucose_meter_screen.dart:40,46`
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
