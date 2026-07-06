---
id: TASK-161
title: 'Round the bolus suggestion down, not to nearest'
status: To Do
assignee: []
created_date: '2026-07-06 09:13'
updated_date: '2026-07-06 12:57'
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
- [ ] #1 Final suggestion and FPU units round DOWN to 0.01 U (or the nearest-rounding is explicitly documented as intended after review — decide)
- [ ] #2 Test pins the direction, e.g. computed 1.238 U → displayed 1.23 U
- [ ] #3 Working/display strings stay consistent with the rounded value
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
