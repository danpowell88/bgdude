---
id: TASK-171
title: 'MealDetector negative case: rise explained by IOB'
status: To Do
assignee: []
created_date: '2026-07-06 09:16'
labels:
  - code-health
  - testing
  - ml
milestone: m-8
dependencies: []
priority: medium
ordinal: 171000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `test/event_detectors_test.dart:26-51` tests a clean unexplained rise and a flat trace, but not the key false-positive case — a rise WITH insulin on board (normal post-bolus excursion) must NOT flag an unannounced meal.

**Reason for change.** That false positive drives alarm fatigue and bad training annotations; the detector needs a pinned negative case.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Test: the same rise shape with a recent bolus present → no detection (or below the confidence threshold)
- [ ] #2 The same negative case covers the confirmation-inbox scan path
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a test reusing the existing rise trace but with a recent bolus/IOB present, asserting no meal detection (or confidence below threshold).
- Add the equivalent negative through the confirmation-inbox scan path.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 9)
- Effort: S
- Where: `test/event_detectors_test.dart`
- Related: TASK-109 (base coverage, done), TASK-48 (wiring)
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
