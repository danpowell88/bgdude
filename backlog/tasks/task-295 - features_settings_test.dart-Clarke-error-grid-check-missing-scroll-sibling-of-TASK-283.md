---
id: TASK-295
title: >-
  features_settings_test.dart: Clarke error grid check missing scroll (sibling
  of TASK-283)
status: Blocked
assignee:
  - Claude
created_date: '2026-07-08 04:15'
updated_date: '2026-07-08 04:16'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 113271
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Found by TASK-219's emulator workflow (dispatch 28915351919): integration_test/features_settings_test.dart's 'Model internals renders its sections' test checked find.text('Clarke error grid') without scrolling first -- same lazy-ListView root cause TASK-283 already fixed in integration_test/app_test.dart, but this is a separate occurrence in a different file that was never fixed there.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Test scrolls to the Clarke error grid section before asserting on it
- [ ] #2 Confirmed via the emulator workflow
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: TASK-219 emulator dispatch 28915351919, 2026-07-08
- File: integration_test/features_settings_test.dart:97-106
- Fixed: added the same scrollUntilVisible call app_test.dart already uses (TASK-283)
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 04:16
---
Started+fixed: added the same scrollUntilVisible call app_test.dart already uses for this exact check (TASK-283).
---

author: Claude
created: 2026-07-08 04:16
---
AC#1 done. AC#2 staying Blocked pending one more dispatch verification. Pipeline verified locally (unaffected by this integration_test/-only change).
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test --coverage test/ green
- [x] #4 Line coverage did not drop -- at or above the ci.yml floor; any new testable code ships with its tests in the same change
- [x] #5 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #6 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #7 doc/user-guide.html updated when the change is user-visible with screenshots
- [ ] #8 Integration test added or extended when a screen/flow changed
- [ ] #9 backlog item updated with comments
<!-- DOD:END -->
