---
id: TASK-137
title: Shared per-step sensitivity-attribution kernel
status: To Do
assignee: []
created_date: '2026-07-06 08:40'
labels:
  - code-health
  - ml
milestone: m-8
dependencies: []
priority: medium
ordinal: 137000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The sorted-CGM → gap-guard → carb-active check → `iob.total().activityUnitsPerMin * isf` modelled-vs-observed delta loop is re-implemented subtly differently in `Autotune.analyseDay` (`lib/ml/autotune.dart:102-134`), `TimeOfDaySensitivityAnalyzer.analyseDay` (`lib/ml/time_of_day_sensitivity.dart:132-159`), `MealDetector` and `CompressionLowDetector` (`lib/ml/event_detectors.dart:54-95,138-160`); each also does an O(carbs) scan per step.

**Reason for change.** Four subtly different copies of the attribution loop drift independently and each pays an O(carbs) scan per step; one kernel fixes both.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A shared iterator yields per-step `(time, gapMin, observedDelta, modelledDelta, carbActive)`
- [ ] #2 All four consumers use it with behaviour pinned by existing tests
- [ ] #3 Carbs are sorted once with a windowed check
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Extract the shared per-step iterator into a new ml helper.
- Sort carbs once and use a windowed active check inside the iterator.
- Convert `Autotune.analyseDay`, `TimeOfDaySensitivityAnalyzer.analyseDay`, `MealDetector`, `CompressionLowDetector` to consume it.
- Keep behaviour pinned by the existing tests for each consumer.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: deep-sweep 2026-07-06 (`lib/ml/autotune.dart:102-134` and siblings)
- Effort: M
- Where: `lib/ml/autotune.dart`, `lib/ml/time_of_day_sensitivity.dart`, `lib/ml/event_detectors.dart`, new shared helper
- Related: keep like-for-like intent of TASK-3
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
