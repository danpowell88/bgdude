---
id: TASK-143
title: Predicted hypo/hyper duration on Predict
status: To Do
assignee: []
created_date: '2026-07-06 08:41'
updated_date: '2026-07-06 12:58'
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
- [ ] #1 Predicted minutes-below-70 / minutes-above-180 are derived from the existing trajectory and interval
- [ ] #2 A "predicted low for ~25 min" style readout is surfaced on Predict
- [ ] #3 Tests cover synthetic trajectories
- [ ] #4 The user guide is updated
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
