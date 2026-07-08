---
id: TASK-296
title: >-
  features_flows_test.dart: what-if explorer Slider drag hit-test miss (sibling
  of TASK-234)
status: Blocked
assignee:
  - Claude
created_date: '2026-07-08 04:15'
updated_date: '2026-07-08 06:15'
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

author: Claude
created: 2026-07-08 06:15
---
New evidence from the nightly emulator dispatch 28920416983 (2026-07-08 06:02): still failing, but the SYMPTOM has changed since the AC#1 ensureVisible fix landed -- this is no longer a hit-test miss (which would show as the Slider/widget not found or an unmoved value), its a genuine wrong-direction numeric result: expected withMoreCarbs greater than withSomeCarbs (>20.6), actual 16.8 -- LOWER, not just insufficiently higher. The test does two sequential drag() calls on the SAME find.byType(Slider).first with growing offsets (60,0) then (120,0) -- each drag() call re-derives its hit-test offset from the sliders CURRENT on-screen position, which shifts after the first drag moves the thumb. Plausible causes worth checking with device access: (a) the second drag lands past the sliders max extent and the drag gesture (down-move-up) registers as a smaller or reversed delta once clamped, (b) pumpAndSettle is not enough for a debounced/async what-if recompute so the second reading races a stale first-drag value, or (c) the slider is a RangeSlider/has snapping behaviour where a large single-gesture jump does not move monotonically with offset. Leaving Blocked (unchanged) -- this needs actual emulator interaction to diagnose which of these it is; I do not have working emulator access in this session (confirmed pre-existing limitation, see memory integration-test-emulator-limitation). AC#2 must NOT be checked -- the fix did not resolve the flake, it just changed its failure mode.
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
