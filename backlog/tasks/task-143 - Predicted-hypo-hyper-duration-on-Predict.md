---
id: TASK-143
title: Predicted hypo/hyper duration on Predict
status: Review
assignee:
  - Claude
created_date: '2026-07-06 08:41'
updated_date: '2026-07-10 10:18'
status: Needs Review
assignee:
  - Claude
created_date: '2026-07-06 08:41'
updated_date: '2026-07-10 14:03'
labels:
  - feature
  - ml
  - insights
milestone: m-7
dependencies: []
priority: medium
ordinal: 702000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The forecaster emits point + interval per horizon (`lib/ml/forecaster.dart:83-103`) and the gate reasons about hypo detection (`lib/ml/error_grid.dart:95-142`), but nothing forecasts how long a predicted low/high will last — clinically the more actionable quantity (treat-now vs ride-it-out); the baseline trajectory already contains minutes below/above threshold across the horizon grid.

**Value.** "Predicted low for ~25 min" changes the treatment decision in a way a point forecast does not.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Predicted minutes-below-70 / minutes-above-180 are derived from the existing trajectory and interval
- [x] #2 A "predicted low for ~25 min" style readout is surfaced on Predict
- [x] #3 Tests cover synthetic trajectories
- [x] #4 The user guide is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Derive predicted minutes-below-70 / minutes-above-180 from the existing trajectory and interval across the horizon grid.
- Surface the duration readout on the Predict screen.
- Add tests on synthetic trajectories.
- Update `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/forecaster.dart:83-103`)
- Effort: M
- Where: `lib/ml/forecaster.dart`, Predict screen, `doc/user-guide.html`
- Related: distinct from TASK-49 and TASK-52; better after TASK-46/47
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-10 10:07
author: Claude Fable 5
created: 2026-07-10 10:42
---
branch: task-143
---

author: Claude
created: 2026-07-10 10:07
---
Started: reading Forecaster/HorizonForecast and the GlucosePredictor's underlying trajectory (PredictionLine) to see what's already computed between horizon grid points before designing minutes-below/above.
---

author: Claude
created: 2026-07-10 10:18
---
implemented-by: Claude (Sonnet 5, session 5ecb6b72-c69b-4afb-b36c-af3d04f85cad) -- new lib/ml/threshold_duration.dart (ThresholdDurationEstimator: piecewise-linear interpolation across the horizon grid (now, +30, +60, +120), summing minutes on the below/above side of a threshold with exact crossing-point interpolation within a straddling segment; two estimates per call -- pointMinutes from the mgdl trajectory, confidentMinutes from the LESS SEVERE interval bound (upper for a low, lower for a high), so confidentMinutes is never longer than pointMinutes); lib/ui/predictions_screen.dart (new _DurationCard: 'Predicted low for ~Nmin' / 'Predicted high for ~Nmin', with an '(at least N min likely)' caveat when the confident estimate is shorter, hidden entirely when nothing is predicted); doc/user-guide.html updated. Thresholds: reused GlucoseThresholds.low(70)/.high(180), matching the existing _OvernightCard on the same screen rather than the user's personalised alert thresholds, for consistency. Tests: test/ml/threshold_duration_test.dart -- full-span/never-crosses/exact-interpolation cases for both below and above, confidentMinutes<=pointMinutes invariant, empty-input safety. Caught my own test-math errors during the first run (two minutesAbove cases assumed 'full 120min' with a current value that was actually BELOW threshold at t=0, which the real crossing-interpolation correctly counted as a partial first segment -- fixed the test fixtures, not the implementation, after manually re-deriving the expected numbers). Rigor-checked the crossing-fraction interpolation (temp-bug: count the whole segment unconditionally instead of the interpolated fraction; confirmed the crossing-point test fails with 120 instead of 105 as predicted; reverted cleanly). Full pipeline green: analyze clean, 1374 tests passing, coverage 68.83% (floor 65%), apk build succeeded. No native Kotlin changed. Integration test: Predict tab already has integration_test coverage (features_flows_test.dart); could not run it live (the emulator's VM-service WebSocket issue noted on TASK-141/305 is still present) -- the new card is purely additive (SizedBox.shrink() when nothing predicted) so the existing test's assertions are unaffected either way.
author: Claude Fable 5
created: 2026-07-10 10:42
---
Moved To Do->In Progress to reflect that work has started: origin/task-143 exists and is 1 commit ahead of main. Recording the branch so the review-and-merge loop can find it and parallel sessions do not duplicate this work. Implementer agent TBD (branch pre-existed this status update).
---

author: Claude
created: 2026-07-10 10:45
---
branch: task-143 (correcting -- was set to In Progress by 3db552f, but the code is actually complete: commit 03ec4f1 on that branch)
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
