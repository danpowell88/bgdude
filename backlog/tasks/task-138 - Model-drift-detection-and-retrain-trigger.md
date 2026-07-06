---
id: TASK-138
title: Model-drift detection and retrain trigger
status: To Do
assignee: []
created_date: '2026-07-06 08:40'
updated_date: '2026-07-06 12:58'
labels:
  - feature
  - ml
  - insights
milestone: m-5
dependencies: []
priority: medium
ordinal: 701600
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `UncertaintyCalibrator.perHorizonRmse` (`lib/ml/uncertainty_calibrator.dart:20-37`) already computes recent live per-horizon RMSE and the model stores a training sigma per horizon, but nothing compares them — a degraded model (new sensor, seasonal change) is only ever replaced on the fixed retrain schedule.

**Value.** Catches silent degradation: the user learns the forecast is drifting and the app retrains out of band instead of waiting for the schedule.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Recent live RMSE is compared to stored sigma per horizon
- [ ] #2 Sustained excess over a factor raises a visible "forecast accuracy drifting" flag and an out-of-band retrain request
- [ ] #3 The drift ratio is logged into the model-run record
- [ ] #4 Unit tests cover synthetic drift
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Compare `UncertaintyCalibrator.perHorizonRmse` to the stored per-horizon training sigma.
- Define the sustained-excess factor and window; raise the drift flag and request an out-of-band retrain.
- Log the drift ratio into the model-run record.
- Add unit tests with synthetic drift.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/uncertainty_calibrator.dart:20-37`)
- Effort: M
- Where: `lib/ml/uncertainty_calibrator.dart`, `lib/ml/forecaster_service.dart`, model-run record
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
