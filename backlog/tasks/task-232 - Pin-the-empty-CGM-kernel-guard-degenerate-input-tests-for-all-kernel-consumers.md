---
id: TASK-232
title: >-
  Pin the empty-CGM kernel guard + degenerate-input tests for all kernel
  consumers
status: Done
assignee:
  - Claude
created_date: '2026-07-07 04:50'
updated_date: '2026-07-07 23:23'
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
- [x] #1 MealDetector tests: empty CGM, single sample, all-gap trace — no throw, empty result
- [x] #2 A shared degenerate-input test covers all four kernel consumers
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 23:18
---
Started: add empty/single-sample/all-gap degenerate-input tests for MealDetector and a shared table-driven group covering all 4 AttributionKernel consumers (MealDetector, CompressionLowDetector, Autotune, TOD analyzer).
---

author: Claude
created: 2026-07-07 23:23
---
Both ACs done in test/event_detectors_test.dart.

AC#1: added 3 MealDetector cases (empty CGM, single sample, all-gap trace) directly pinning the exact bug class from commit a76487e (sorted.first.time accessed before the kernel's own i=1 loop, unguarded on an empty list).

AC#2: added a table-driven 'degenerate CGM input across all 4 kernel consumers' group (12 tests = 4 consumers x 3 degenerate cases) covering MealDetector, CompressionLowDetector, Autotune.analyseDay and TimeOfDaySensitivityAnalyzer.analyseDay. Traced each consumer's own loop shape first (not just assumed the kernel's safety was enough): AttributionKernel.steps()'s  is empty/single-sample-safe by construction (0 or 1 never satisfies i<length), and CompressionLowDetector's own  is too -- MealDetector was the ONLY one with an unguarded pre-loop .first access outside the kernel's loop, matching the ticket's own tracing. Autotune/TOD analyzer were already safe but had nothing pinning that before this sweep.

Rigor check: commented out the sorted.isEmpty guard, reran -- both the direct MealDetector test and the table-driven group's MealDetector/empty case failed with the exact predicted 'StateError: No element'; every other consumer's degenerate case stayed green (confirming they don't depend on this guard). Reverted; git diff clean.

Pipeline: build_runner build, flutter analyze clean, flutter test --coverage test/ 1150/1150 green, coverage 67.5% (floor-compliant), flutter build apk --debug succeeded. No native Kotlin, no user-visible change.
---

author: Claude
created: 2026-07-07 23:23
---
Correction to the previous comment: two inline code snippets were eaten by shell backtick expansion. For the record: AttributionKernel.steps() uses for (i = 1; i < length; i++), and CompressionLowDetector uses for (i = 2; i < length - 2; i++) -- both are empty/single-sample-safe by construction, as stated.
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
