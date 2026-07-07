---
id: TASK-232
title: >-
  Pin the empty-CGM kernel guard + degenerate-input tests for all kernel
  consumers
status: To Do
assignee: []
created_date: '2026-07-07 04:50'
labels:
  - code-health
  - testing
  - ml
milestone: m-8
dependencies: []
priority: medium
ordinal: 113230
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Commit a76487e fixed an empty-CGM crash that the TASK-137 kernel conversion shipped (its own message notes the crash was masked by a piped exit code) by restoring the `if (sorted.isEmpty) return out;` guard in `lib/ml/event_detectors.dart:57` — but added no test, so the exact bug class that reached main can silently return on the next refactor. Tracing the four kernel consumers: `MealDetector` was the only crashing path (Autotune, the TOD analyzer and `CompressionLowDetector` degrade safely), but none of the four has a test exercising empty, single-sample or all-gap input — precisely the fragile surface the shared `AttributionKernel` introduced (`steps` starts at i=1; consumers seeding off `sorted.first` are the trap).

**Reason for change.** A crash that shipped once and is fixed without a pin is a regression waiting to happen.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 MealDetector tests: empty CGM, single sample, all-gap trace — no throw, empty result
- [ ] #2 A shared degenerate-input test covers all four kernel consumers
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add the three MealDetector cases to `test/event_detectors_test.dart`.
- Add a table-driven degenerate-input group over Autotune, TOD analyzer, both detectors.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: hourly quality check 2026-07-07 #2 (finding 1)
- Effort: S
- Where: test/event_detectors_test.dart, lib/ml/event_detectors.dart:57
- Related: TASK-137 (introduced), a76487e (the unpinned fix)
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
