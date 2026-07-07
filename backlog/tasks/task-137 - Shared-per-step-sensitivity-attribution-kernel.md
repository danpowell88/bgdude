---
id: TASK-137
title: Shared per-step sensitivity-attribution kernel
status: Done
assignee:
  - Claude
created_date: '2026-07-06 08:40'
updated_date: '2026-07-07 04:17'
labels:
  - code-health
  - ml
milestone: m-8
dependencies: []
priority: medium
ordinal: 106700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The sorted-CGM → gap-guard → carb-active check → `iob.total().activityUnitsPerMin * isf` modelled-vs-observed delta loop is re-implemented subtly differently in `Autotune.analyseDay` (`lib/ml/autotune.dart:102-134`), `TimeOfDaySensitivityAnalyzer.analyseDay` (`lib/ml/time_of_day_sensitivity.dart:132-159`), `MealDetector` and `CompressionLowDetector` (`lib/ml/event_detectors.dart:54-95,138-160`); each also does an O(carbs) scan per step.

**Reason for change.** Four subtly different copies of the attribution loop drift independently and each pays an O(carbs) scan per step; one kernel fixes both.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A shared iterator yields per-step `(time, gapMin, observedDelta, modelledDelta, carbActive)`
- [x] #2 All four consumers use it with behaviour pinned by existing tests
- [x] #3 Carbs are sorted once with a windowed check
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 04:10
---
Started: extract a shared per-step attribution iterator (time/gap/observedDelta/modelledDelta/carbActive) with carbs sorted once + windowed active check; convert the four consumers; behaviour pinned by their existing tests.
---

author: Claude
created: 2026-07-07 04:15
---
Done.
---

author: Claude
created: 2026-07-07 04:17
---
Post-close fix: commit 4b8798f briefly broke the empty-CGM path (sorted.first on an empty list in MealDetector) — a piped exit code masked 6 test failures before push. Guard added and full suite re-verified green in the follow-up commit.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
New lib/ml/attribution_kernel.dart: AttributionKernel.steps() yields (time, gapMinutes, isGapBreak, observedDelta, modelledDelta, insulinDragPerMin, carbActive, segment) per adjacent pair; carbs sorted once with a forward-window check (pointer + max-absorption prune) replacing the O(carbs) scan per step. Autotune/TOD analyzer/MealDetector consume the iterator keeping only their window/bucket policies; CompressionLowDetector consumes the shared insulinDragPerMinAt static (its 3-point shape doesn't iterate pairs — noted as the honest fit for AC#2). Arithmetic order preserved exactly (negation-before-multiply is IEEE-exact) so all existing suites pin behaviour unchanged (726 tests green). Verified: analyze clean, APK builds.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [x] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [x] #6 doc/user-guide.html updated when the change is user-visible
- [x] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
