---
id: TASK-136
title: Single source for the widening-band fallback sigma
status: To Do
assignee: []
created_date: '2026-07-06 08:39'
updated_date: '2026-07-06 12:58'
labels:
  - code-health
  - ml
  - cleanup
milestone: m-8
dependencies: []
priority: low
ordinal: 110300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The deterministic-only sigma `9 + horizonMinutes * 0.30` is copy-pasted three times: `lib/ml/forecaster.dart:66` (`NoResidualModel.correct`) and twice in `lib/ml/residual_gbm_model.dart:45-46,49` (untrained-horizon and missing-sigma paths); tuning it requires three edits that can drift.

**Reason for change.** The fallback band width is a safety-relevant constant; three copies invite silent divergence.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One shared function/const lives next to `kForecastZ90`
- [ ] #2 All three sites call it
- [ ] #3 A test pins the value
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add a shared `fallbackSigma(horizonMinutes)` next to `kForecastZ90`.
- Replace the three inline copies with calls to it.
- Add a test pinning the value.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/forecaster.dart:66`, `lib/ml/residual_gbm_model.dart:45-49`)
- Effort: S
- Where: `lib/ml/forecaster.dart`, `lib/ml/residual_gbm_model.dart`
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
