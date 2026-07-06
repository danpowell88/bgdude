---
id: TASK-168
title: 'Property tests: band ordering, COB conservation, aggregate IOB monotonicity'
status: To Do
assignee: []
created_date: '2026-07-06 09:15'
updated_date: '2026-07-06 12:57'
labels:
  - code-health
  - testing
  - ml
milestone: m-8
dependencies: []
priority: medium
ordinal: 107400
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** No test asserts `lowerMgdl <= mgdl <= upperMgdl` for every horizon of a real `Forecaster` output post-calibration — the calibrator mutates the band via ±1.64·sigma, so a sign/clamp bug could cross the band and mislead a hypo decision; only one hand-built forecast is tested in `test/rescue_and_uncertainty_test.dart:68-81`. `carb_math` tests only the triangle peak, not that `absorptionRate` integrates to grams. Aggregate IOB (multiple boluses) monotone-decreasing after the last dose is untested (only the single-curve fraction).

**Reason for change.** These invariants are cheap to state, safety-relevant, and currently unguarded against sign/clamp/summation bugs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Property test over the sim day + randomized sigmas: lower <= point <= upper for all horizons after calibration
- [ ] #2 COB conservation: `absorptionRate` integrates to grams over the window
- [ ] #3 Aggregate IOB is monotone-decreasing after the last bolus
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a property test running the real `Forecaster` over the simulated day with randomized sigmas, asserting band ordering per horizon post-calibration.
- Add a `carb_math` test integrating `absorptionRate` over the window and comparing to the meal grams.
- Add an aggregate-IOB test with multiple boluses asserting monotone decrease after the last dose.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 6)
- Effort: S–M
- Where: `test/rescue_and_uncertainty_test.dart`, `test/` (carb/insulin math tests), `lib/ml/`, `lib/analytics/`
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
