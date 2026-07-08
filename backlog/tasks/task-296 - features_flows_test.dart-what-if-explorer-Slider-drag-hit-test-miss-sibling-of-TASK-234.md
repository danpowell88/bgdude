---
id: TASK-296
title: >-
  features_flows_test.dart: what-if explorer Slider drag hit-test miss (sibling
  of TASK-234)
status: Blocked
assignee:
  - Claude
created_date: '2026-07-08 04:15'
updated_date: '2026-07-08 04:16'
labels: []
milestone: m-8
dependencies: []
priority: medium
ordinal: 113272
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Found by TASK-219's emulator workflow (dispatch 28915351919): 'Predict tab exposes the what-if explorer with sliders' failed -- scrollUntilVisible(find.text('What-if explorer'), ...) stops once the label enters the viewport, but the Slider widget further down the same section can still sit at the edge, so drag()'s derived hit-test offset misses it (same root cause TASK-234 diagnosed for tap(), here for drag()).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The Slider is ensureVisible'd before drag() derives its hit-test offset
- [ ] #2 Confirmed via the emulator workflow
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: TASK-219 emulator dispatch 28915351919, 2026-07-08
- File: integration_test/features_flows_test.dart:50-55
- Fixed: added tester.ensureVisible(find.byType(Slider).first) + pumpAndSettle before the first drag()
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 04:16
---
Started+fixed: added tester.ensureVisible(find.byType(Slider).first) + pumpAndSettle before the first drag() call, matching the tapListTile pattern from TASK-234/235 applied to drag() instead of tap().
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
