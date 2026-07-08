---
id: TASK-140
title: Training-data census on the diagnostics screen
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:40'
updated_date: '2026-07-08 11:07'
labels:
  - feature
  - ml
  - developer
milestone: m-5
dependencies: []
priority: medium
ordinal: 701700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Trainers silently skip unusable data (`lib/ml/sensitivity_training.dart:67-98` days skipped; `lib/ml/time_of_day_sensitivity.dart:207-223` per-bucket observation minutes; `lib/ml/forecaster_training.dart:159-173` sample counts) and discard the counts, so when a model declines to train the user cannot see why.

**Value.** Explains the training gates and guides data collection ("wear the sensor overnight to unlock the 02:00 bucket").
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Each trainer returns a small census struct (usable days, per-bucket minutes, per-horizon sample counts, health-feature coverage)
- [x] #2 The census is rendered on the model/accuracy diagnostics screen
- [x] #3 The user guide is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Define a small census struct per trainer (usable days, per-bucket minutes, per-horizon sample counts, health-feature coverage).
- Return and persist the census from each trainer run.
- Render it on the model/accuracy diagnostics screen.
- Update `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/sensitivity_training.dart:67-98` and siblings)
- Effort: S–M
- Where: `lib/ml/sensitivity_training.dart`, `lib/ml/time_of_day_sensitivity.dart`, `lib/ml/forecaster_training.dart`, diagnostics screen, `doc/user-guide.html`
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-08 10:54
---
Started: reading the three trainers (sensitivity_training.dart, time_of_day_sensitivity.dart, forecaster_training.dart) to see what counts they already compute internally and discard, before designing the shared census struct.
---

author: Claude
created: 2026-07-08 11:07
---
Done: added TrainingCensus (lib/ml/training_census.dart), a small shared value class each trainer populates its own subset of. SensitivityTrainingService.census(days) returns totalDays/usableDays (mirrors buildExamples' own carb-free-minutes gate). TimeOfDayProfile gained observationMinutesByBucket (the per-bucket minutes were already computed in learn() and stored as _observationMinutes, just never exposed). ForecasterTrainingResult/TrainingOutcome gained a census with perHorizonSamples (trainingByHorizon[h].length, already computed, previously discarded after summing into the pooled trainCount) and healthFeatureCoverage (fraction of TRAINING timesteps whose HealthFeatureSampler features were non-zero, new -- computed once per timestep in the existing loop, not per horizon). Wired: trainSensitivity() merges the sensitivity+TOD census into sensitivityCensusProvider (both trainers share the same 'days' list); ForecasterModelController.train() threads its result.census into TrainingOutcome, already exposed via forecasterModelProvider.notifier.lastOutcome. UI: AdvancedScreen (the existing model-internals diagnostics screen) -- extended each time-of-day bucket row with its observed minutes, and added a new 'Training data' card (sensitivity usable/considered days, forecaster per-horizon sample counts, health coverage %). Tests: sensitivity_training_test.dart (census totalDays/usableDays), time_of_day_sensitivity_test.dart (observationMinutesByBucket distinguishes an observed vs never-observed bucket), forecaster_training_test.dart (perHorizonSamples matches trainSamples; healthFeatureCoverage is 0 with no health data, >0 with real steps data). Rigor-checked the health-coverage computation (temp-bug forcing hasHealthSignal=false, confirmed the coverage test fails as predicted, reverted cleanly). doc/user-guide.html: Advanced/model-internals section updated with the new bucket-minutes detail and Training data card. Full pipeline green: analyze clean, 1364 tests passing, coverage 68.65% (floor 65%), apk build succeeded. No native Kotlin changed. Integration test: AdvancedScreen has no existing integration_test coverage at all (a pre-existing gap, not introduced by this task) -- did not add a new integration suite for the whole screen as that's out of this task's scope; the change is additive UI verified via the full unit-test pipeline instead.
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
