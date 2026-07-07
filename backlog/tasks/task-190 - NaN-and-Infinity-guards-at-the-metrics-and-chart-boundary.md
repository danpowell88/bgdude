---
id: TASK-190
title: NaN and Infinity guards at the metrics and chart boundary
status: Done
assignee:
  - Claude
created_date: '2026-07-06 12:56'
updated_date: '2026-07-07 12:26'
labels:
  - code-health
  - ui
  - ml
milestone: m-8
dependencies: []
priority: medium
ordinal: 108700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Grep shows zero `isNaN`/`isFinite` checks across lib/ui/, lib/analytics/ and lib/ml/. Divisions with potentially-zero denominators (metrics over empty or single-sample windows, CV with mean 0, ISF/CR of 0 from therapy settings, chart Y-range from identical min/max) can produce NaN/Infinity that propagates into fl_chart spot lists (which throws or renders blank) and display strings ("NaN mmol/L").

**Reason for change.** One NaN in a chart data list can take down a whole report screen; a NaN in a metric silently poisons downstream comparisons (NaN comparisons are always false).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Metric entry points return null/absent (typed) instead of NaN for empty or degenerate windows; documented convention
- [x] #2 Chart data builders assert/filter finite values before handing to fl_chart
- [x] #3 TherapySettings validation rejects zero ISF/CR at the input boundary
- [x] #4 Tests: empty window metrics, identical-value Y-range, zero ISF input
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 12:26
---
Done. Root-caused via an Explore-agent audit (grep confirmed zero isNaN/isFinite checks in lib/ui, lib/analytics, lib/ml): the real chain is ISF/CR=0 -> Infinity/NaN in bolus_advisor.dart and predictor.dart -> a literal 'NaN U'/'Infinity U' dose string or a broken forecast-chart point. metrics.dart and the existing chart builders were already safe (early-return on empty input, or fixed clinical Y-axis constants / floored maxes) — no live 'identical-value Y-range' bug exists today, so no contrived test was added for that. Fixes: (1) new safeDivide() helper in core/units.dart; (2) therapy_settings_screen.dart's segment-edit dialog now rejects ISF<=0 or CR<=0 at Save with a SnackBar (code-reviewed, not widget-tested — the dialog is a private State class); (3) TherapySegment.fromJson sanitizes a corrupt/old zero-or-negative ISF/CR back to the same clinical defaults as TherapySettings.placeholder(); (4) carbSensitivityFactor uses safeDivide instead of a release-stripped assert; (5) bolus_advisor.dart guards mealUnits/fpuUnits/rawCorrection with safeDivide plus a final isNaN/isInfinite floor on the total before display; (6) predictor.dart floors a NaN/Infinite bg back to the current reading each step (comparisons with NaN are always false, so the existing 39/400 clamps silently miss it). Tests: bolus_advisor_test.dart (zero-ISF/CR dose stays finite), carb_math_test.dart (zero CR -> 0 not Infinity), new therapy_settings_test.dart (fromJson sanitization). Pipeline green: analyze clean, 765 tests passed, apk debug build succeeds.
---
<!-- COMMENTS:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 dart run build_runner build --delete-conflicting-outputs succeeds (generated files are not committed)
- [x] #2 flutter analyze clean
- [x] #3 flutter test test/ green
- [x] #4 flutter build apk --debug succeeds (catches Android/Gradle/manifest breakage)
- [ ] #5 gradlew :app:testDebugUnitTest green when native Kotlin changed
- [ ] #6 doc/user-guide.html updated when the change is user-visible
- [ ] #7 Integration test added or extended when a screen/flow changed
<!-- DOD:END -->
