---
id: TASK-174
title: Autotune case with model-independent ground truth
status: To Do
assignee: []
created_date: '2026-07-06 09:17'
updated_date: '2026-07-06 12:58'
labels:
  - code-health
  - testing
  - ml
milestone: m-8
dependencies: []
priority: low
ordinal: 110600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `test/autotune_test.dart:24-37` synthesizes the CGM trace using the production `InsulinModel` and asserts Autotune recovers the injected factor — a legitimate round-trip, but an insulin-curve bug would be embedded identically in the ground truth and still read ≈1.

**Reason for change.** At least one Autotune case should derive its expected multiplier from data the production model did not generate.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One autotune case whose expected multiplier derives from a hand-specified linear glucose fall independent of `InsulinModel`
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Construct a CGM trace as a hand-specified linear fall for a known bolus and compute the expected sensitivity multiplier by hand.
- Add the case to `test/autotune_test.dart` alongside the existing round-trip.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 12)
- Effort: S
- Where: `test/autotune_test.dart`
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
