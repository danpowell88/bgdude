---
id: TASK-168
title: 'Property tests: band ordering, COB conservation, aggregate IOB monotonicity'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:15'
updated_date: '2026-07-07 07:16'
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
- [x] #1 Property test over the sim day + randomized sigmas: lower <= point <= upper for all horizons after calibration
- [x] #2 COB conservation: `absorptionRate` integrates to grams over the window
- [x] #3 Aggregate IOB is monotone-decreasing after the last bolus
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 07:13
---
Started: property tests — calibrated band ordering over the sim day with randomized sigmas, COB conservation (absorptionRate integrates to grams), aggregate IOB monotone-decreasing after the last bolus.
---

author: Claude
created: 2026-07-07 07:16
---
Done.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
New test/property_invariants_test.dart: (1) sim-day sweep — real forecasts every ~2h, 20 randomized RMSE maps each (0-120 mg/dL incl. clamp edges), lower<=point<=upper asserted for every horizon (>100 checks enforced); (2) COB conservation via trapezoid integration to within 1% for 4 grams/absorption combos incl. the min-absorption clamp, plus rate == -dCOB/dt agreement; (3) stacked-bolus IOB monotone-decreasing from the last dose, non-negative, and fully decayed past DIA. Verified: analyze clean, 733 tests green, APK builds.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
