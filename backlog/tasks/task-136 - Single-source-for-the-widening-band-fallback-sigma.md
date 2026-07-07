---
id: TASK-136
title: Single source for the widening-band fallback sigma
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:39'
updated_date: '2026-07-07 15:22'
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
- [x] #1 One shared function/const lives next to `kForecastZ90`
- [x] #2 All three sites call it
- [x] #3 A test pins the value
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 15:19
---
Started: deduplicating the 9 + horizonMinutes*0.30 fallback sigma into a shared function next to kForecastZ90.
---

author: Claude
created: 2026-07-07 15:22
---
Added fallbackSigma(horizonMinutes) next to kForecastZ90 in lib/ml/forecaster.dart; replaced all three copies (NoResidualModel.correct, and both the untrained-horizon + missing-per-horizon-sigma branches in ResidualGbmModel.correct) with calls to it. New test/forecaster_test.dart pins the exact curve at 4 horizons and asserts NoResidualModel delegates to it; tightened residual_gbm_test.dart's existing untrained-horizon test to assert against fallbackSigma(...) directly instead of a hand-duplicated literal, so a future edit to the formula can't silently desync the test from the implementation either. flutter analyze clean, flutter test test/ green (945 tests), flutter build apk --debug succeeded. No user-visible/native/screen changes -- DoD #5/#6/#7 n/a.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
