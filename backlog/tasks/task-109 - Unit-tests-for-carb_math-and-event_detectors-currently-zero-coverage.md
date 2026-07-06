---
id: TASK-109
title: Unit tests for carb_math and event_detectors (currently zero coverage)
status: Done
assignee: []
created_date: '2026-07-06 04:54'
updated_date: '2026-07-06 08:07'
labels:
  - code-health
  - testing
  - ml
  - "\U0001F512 safety"
milestone: m-8
dependencies:
  - TASK-108
priority: high
ordinal: 109000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Cross-referencing every test import against lib/ shows two pure, safety-adjacent modules with no direct unit tests:

- `lib/analytics/carb_math.dart` — the bilinear COB model (`CarbModel.cobFraction/cob/absorptionRate`) and `carbSensitivityFactor`. Feeds the advisor, predictor and Autotune.
- `lib/ml/event_detectors.dart` — `MealDetector` (unannounced-meal detection) and `CompressionLowDetector` (nocturnal artifact exclusion). Gates what is excluded from training labels and what raises insights.

**Reason for change.** These are deterministic engines feeding dosing-adjacent outputs — the easiest possible things to test and among the most consequential if wrong. Also fulfils the explicit "test MealDetector first" precondition of TASK-48.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 carb_math: cobFraction is 1 at t<=0 and 0 at t>=duration, monotonically decreasing; area under absorptionRate equals grams; carbSensitivityFactor = ISF/CR
- [ ] #2 MealDetector: fires only on a sustained unexplained rise past threshold; respects the minimum-duration rule
- [ ] #3 CompressionLowDetector: requires drop + rebound; suppressed when IOB explains the drop
- [ ] #4 Uses the shared fixtures from test/support/ (TASK-108)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Read both modules and pin current behaviour with characterisation tests first.
- Add test/carb_math_test.dart and test/event_detectors_test.dart using the shared builders.
- Property-style checks for COB monotonicity and area; scenario tables for the detectors.
- `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: code-health survey 2026-07-06 (test finding 2)
- Effort: S–M
- Related: TASK-48 (meal detection wiring) says to test MealDetector first — this task is that step
<!-- SECTION:NOTES:END -->
