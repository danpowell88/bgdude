---
id: TASK-161
title: 'Round the bolus suggestion down, not to nearest'
status: Done
assignee:
  - Claude
created_date: '2026-07-06 09:13'
updated_date: '2026-07-06 22:16'
labels:
  - code-health
  - dosing-math
  - "\U0001F512 safety"
milestone: m-8
dependencies: []
priority: high
ordinal: 100900
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** `lib/analytics/bolus_advisor.dart:287` rounds the final suggestion with `(total*100).roundToDouble()/100` — nearest-rounding can round an advisory insulin dose UP; the conservative convention is to round down to the deliverable 0.01 U increment. FPU units at `lib/analytics/bolus_advisor.dart:177` have the same pattern. No test pins the rounding direction (all use `closeTo` with tolerance ≥0.05).

**Reason for change.** An advisory dose should never be rounded upward; rounding down is the conservative, deliverable-increment convention.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Final suggestion and FPU units round DOWN to 0.01 U (or the nearest-rounding is explicitly documented as intended after review — decide)
- [x] #2 Test pins the direction, e.g. computed 1.238 U → displayed 1.23 U
- [x] #3 Working/display strings stay consistent with the rounded value
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Review the rounding convention and decide: floor to 0.01 U vs documented nearest-rounding.
- Change the final-suggestion rounding at `bolus_advisor.dart:287` and the FPU-units rounding at `:177` accordingly.
- Add direction-pinning tests (1.238 → 1.23) and check working/display strings match the rounded value.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: accuracy-reliability sweep 2026-07-06 (accuracy finding 1)
- Effort: S
- Where: `lib/analytics/bolus_advisor.dart`
- Related: TASK-101 (compute/presenter split) — coordinate if concurrent
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 22:12
---
Started: switch final-suggestion and FPU-unit rounding to floor at 0.01 U (conservative deliverable increment) and pin the direction with tests.
---

author: Claude
created: 2026-07-06 22:16
---
Done (commit e342ada). Note an interleaved commit 1d1d630 appeared upstream before this push (rebase happened cleanly).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Decision: floor (round down) to the deliverable 0.01 U increment — advisory doses must never round upward. _floorToIncrement (with 1e-9 epsilon so exact increments like 1.23 survive binary-float error) applied to the final total and the FPU extended units; the 'Meal insulin' working line displays the floored value so working can never read above the suggestion. Direction pinned: 1.238->1.23, FPU 1.247->1.24, exact-increment preservation, and working/Suggested string consistency. Verified: analyze clean, 631 tests green, debug APK builds. Commit e342ada.
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
