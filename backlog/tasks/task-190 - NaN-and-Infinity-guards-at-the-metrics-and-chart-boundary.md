---
id: TASK-190
title: NaN and Infinity guards at the metrics and chart boundary
status: To Do
assignee: []
created_date: '2026-07-06 12:56'
labels:
  - code-health
  - ui
  - ml
milestone: m-8
dependencies: []
priority: medium
ordinal: 190000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Grep shows zero `isNaN`/`isFinite` checks across lib/ui/, lib/analytics/ and lib/ml/. Divisions with potentially-zero denominators (metrics over empty or single-sample windows, CV with mean 0, ISF/CR of 0 from therapy settings, chart Y-range from identical min/max) can produce NaN/Infinity that propagates into fl_chart spot lists (which throws or renders blank) and display strings ("NaN mmol/L").

**Reason for change.** One NaN in a chart data list can take down a whole report screen; a NaN in a metric silently poisons downstream comparisons (NaN comparisons are always false).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Metric entry points return null/absent (typed) instead of NaN for empty or degenerate windows; documented convention
- [ ] #2 Chart data builders assert/filter finite values before handing to fl_chart
- [ ] #3 TherapySettings validation rejects zero ISF/CR at the input boundary
- [ ] #4 Tests: empty window metrics, identical-value Y-range, zero ISF input
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Audit division sites in metrics.dart, analytics and chart builders; add finite guards or null returns.
- Add a small `finiteOrNull` helper; sweep chart spot builders.
- Validate ISF/CR > 0 in the therapy settings form and fromJson.
- Add the three test groups.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: stability sweep 2026-07-06 (verified: zero finite-guards in ui/analytics/ml)
- Effort: M
- Where: lib/analytics/metrics.dart, lib/ui/widgets + reports chart builders, therapy settings validation
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
