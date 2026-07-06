---
id: TASK-140
title: Training-data census on the diagnostics screen
status: To Do
assignee: []
created_date: '2026-07-06 08:40'
labels:
  - feature
  - ml
  - developer
milestone: m-5
dependencies: []
priority: medium
ordinal: 140000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Trainers silently skip unusable data (`lib/ml/sensitivity_training.dart:67-98` days skipped; `lib/ml/time_of_day_sensitivity.dart:207-223` per-bucket observation minutes; `lib/ml/forecaster_training.dart:159-173` sample counts) and discard the counts, so when a model declines to train the user cannot see why.

**Value.** Explains the training gates and guides data collection ("wear the sensor overnight to unlock the 02:00 bucket").
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each trainer returns a small census struct (usable days, per-bucket minutes, per-horizon sample counts, health-feature coverage)
- [ ] #2 The census is rendered on the model/accuracy diagnostics screen
- [ ] #3 The user guide is updated
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
