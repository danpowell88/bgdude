---
id: TASK-160
title: Reference-pin clinical formulas with independent literals
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:13'
updated_date: '2026-07-07 03:00'
labels:
  - code-health
  - testing
  - ml
  - dosing-math
milestone: m-8
dependencies: []
priority: high
ordinal: 102600
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
- [x] #1 LBGI/HBGI pinned to model-independent anchors: f=0 at BG 112.5 mg/dL; steady BG 50 → LBGI ≈ 22.5 (hand-computed)
- [x] #2 GRI test uses hand-calculated literals, not re-derived weights
- [x] #3 IOB curve pinned for DIA=360/peak=75: `iobFraction(75)≈0.694`, `iobFraction(180)≈0.208`, activity max at exactly t=peak
- [x] #4 Clarke boundary pins at ref 290/291, 240, 130 and A-edge pairs (100,120)→A vs (100,121)→not A
- [x] #5 CV pinned on an alternating 100/200 trace (CV 33.3%) and variabilityHigh at 35.9 vs 36.0
- [x] #6 `_percentile` documented as type-7 and pinned ([10,20,30,40] p25=17.5) with a minimum-count guard or flag for sparse AGP buckets
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 02:54
---
Started: hand-computed, model-independent anchors per formula (LBGI/HBGI, GRI, IOB curve, Clarke boundaries, CV boundary, percentile type-7 doc + sparse guard), derivations recorded in test comments.
---

author: Claude
created: 2026-07-07 03:00
---
Done (commit b417e3d). AC#6 chose the flag (AgpBucket.sparse) over a hard guard so existing AGP rendering is unchanged; consumers can de-emphasise sparse buckets when the UI work happens.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All six formula families now have hand-computed, model-independent anchors with derivations in the test comments: (1) LBGI steady-50 = 22.5004, f(112.5)=0; (2) GRI mixed-trace literals 59.0 (metrics from raw CGM) and 44.2 (band-constructed); (3) IOB DIA360/peak75: iob(75)=0.6943, iob(180)=0.2082, activity max exactly at t=75; (4) Clarke pins: 290/400=C vs 291/401=B, 240/100=D vs 239/100=B, lower-C straddled at ref 170 (7/5 not exactly representable in binary FP), A-edges (100,120)/(100,121) and (100,80)/(100,79); (5) CV alternating 100/200 = 33.33% and variabilityHigh flipping 35.9->36.0; (6) _percentile documented as Hyndman-Fan type-7 with the [10,20,30,40] p25=17.5 pin and a new AgpBucket.sparse flag (count<5) for thin buckets. Verified: analyze clean, 689 tests green, debug APK builds. Commit b417e3d.
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
