---
id: TASK-3
title: P0-3 Autotune & TOD sensitivity compare like-for-like (after P0-2)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 04:13'
labels:
  - roadmap
  - §1-P0
  - phase-1
  - dosing-math
  - detail-needed
dependencies: []
priority: high
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** "Autotune" is bgdude's routine that learns, from past days, how sensitive you are to insulin and carbs; a related model learns how that sensitivity changes by time of day. Both derive their answers from the same insulin model that P0-2 is fixing, so today they measure insulin's effect against a distorted baseline.

**Reason for change.** Until they compare on the same (corrected) basis as P0-2, the sensitivity the app learns is systematically wrong. A well-controlled person fasting overnight should come out looking normal, not resistant. This mostly falls out of the P0-2 fix.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Fasting well-tuned user scores ≈1.0 in Autotune
- [ ] #2 TOD sensitivity consistent with net-insulin model
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** In autotune.dart / time_of_day_sensitivity.dart, align the insulin-effect basis with P0-2 (net insulin). A well-tuned fasting user should produce ratios ≈1.0.

**Testing.** Fasting well-tuned user scores ≈1.0 in Autotune and TOD sensitivity; add a direct test. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able). `flutter analyze` clean and `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P0-3
Effort: M (falls out of P0-2)
Where: autotune.dart, time_of_day_sensitivity.dart
Depends on: P0-2
Roadmap status: open

detail-needed (2026-07-06): blocked on TASK-2 (P0-2). This 'falls out of' the net-insulin model change; can't be done or validated until P0-2's approach + validation data are settled.
<!-- SECTION:NOTES:END -->
