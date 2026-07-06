---
id: TASK-139
title: Advisory ISF/CR suggestions from the learned sensitivity profile
status: To Do
assignee: []
created_date: '2026-07-06 08:40'
updated_date: '2026-07-06 12:58'
labels:
  - feature
  - ml
  - insights
  - dosing-math
  - "\U0001F512 safety"
milestone: m-7
dependencies:
  - TASK-3
  - TASK-21
priority: medium
ordinal: 700300
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `BasalRecommender` (`lib/ml/basal_recommender.dart`) already turns the TOD profile into conservative, gated basal suggestions, but the daily sensitivity multiplier (`DayResult.sensitivityMultiplier`, `lib/ml/autotune.dart:25-42`) and TOD profile carry ISF/CR implications that are never surfaced.

**Value.** A read-only "your ISF/CR may be ~X% off in this window" advisory fits the charter and closes the loop on data the app already learns.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 An `IsfCrRecommender` consumes the same profile + confidence gates as `BasalRecommender`
- [ ] #2 Resistant/sensitive multipliers map to clamped ISF/CR deltas with rationale strings
- [ ] #3 It reuses `BasalRecommender` confidence/minChange thresholds
- [ ] #4 Suggestions are surfaced on the therapy/insights screen with the working shown
- [ ] #5 The user guide is updated
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `IsfCrRecommender` consuming the TOD profile and daily sensitivity multiplier with the existing confidence gates.
- Map resistant/sensitive multipliers to clamped ISF/CR deltas with rationale strings.
- Reuse `BasalRecommender` confidence/minChange thresholds.
- Surface the advisory on the therapy/insights screen with the working shown.
- Update `doc/user-guide.html`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/basal_recommender.dart`, `lib/ml/autotune.dart:25-42`)
- Effort: M
- Where: new `lib/ml/isf_cr_recommender.dart`, therapy/insights screen, `doc/user-guide.html`
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
