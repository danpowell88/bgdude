---
id: TASK-160
title: Reference-pin clinical formulas with independent literals
status: To Do
assignee: []
created_date: '2026-07-06 09:13'
labels:
  - code-health
  - testing
  - ml
  - dosing-math
milestone: m-8
dependencies: []
priority: high
ordinal: 160000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Several formula tests re-derive the production expression and compare it to itself, proving nothing: `test/risk_metrics_test.dart:13-18` copies the Kovatchev LBGI/HBGI expression verbatim, and `test/metrics_test.dart:48-63` re-derives the GRI weights. Other correct formulas have only property tests and no value pins.

- Exponential IOB curve (`lib/analytics/insulin_math.dart:34-68`): no curve-value pin.
- Clarke grid boundary segments (`lib/ml/error_grid.dart:45-74`): ref=290 vs 291 upper-C ceiling, ref=240 D onset, ref=130 lower-C onset, exact ±20% A-band edges untested.
- CV/36% labile boundary (`lib/analytics/metrics.dart:75-79,153`): only tested at CV=0.
- AGP `_percentile` (`lib/analytics/metrics.dart:207-241`): type-7 interpolation undocumented, sparse buckets unguarded.

**Reason for change.** A constant regression (e.g. 1.084→1.026) would pass every current test; each clinical formula needs at least one hand-computed, model-independent anchor.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 LBGI/HBGI pinned to model-independent anchors: f=0 at BG 112.5 mg/dL; steady BG 50 → LBGI ≈ 22.5 (hand-computed)
- [ ] #2 GRI test uses hand-calculated literals, not re-derived weights
- [ ] #3 IOB curve pinned for DIA=360/peak=75: `iobFraction(75)≈0.694`, `iobFraction(180)≈0.208`, activity max at exactly t=peak
- [ ] #4 Clarke boundary pins at ref 290/291, 240, 130 and A-edge pairs (100,120)→A vs (100,121)→not A
- [ ] #5 CV pinned on an alternating 100/200 trace (CV 33.3%) and variabilityHigh at 35.9 vs 36.0
- [ ] #6 `_percentile` documented as type-7 and pinned ([10,20,30,40] p25=17.5) with a minimum-count guard or flag for sparse AGP buckets
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Work one formula at a time: LBGI/HBGI anchors, then GRI literals, then IOB curve pins, then Clarke boundary pins, then CV boundary, then `_percentile` documentation + pin + sparse-bucket guard.
- Hand-compute each expected literal outside the codebase and record the derivation in the test comment.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (test-quality finding 2)
- Effort: M
- Where: `test/risk_metrics_test.dart`, `test/metrics_test.dart`, `lib/analytics/insulin_math.dart`, `lib/ml/error_grid.dart`, `lib/analytics/metrics.dart`
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
