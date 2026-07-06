---
id: TASK-2
title: P0-2 Predictor models insulin effect from net insulin (EGP baseline)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §1-P0
  - phase-1
  - dosing-math
dependencies: []
priority: high
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Model insulin effect from net insulin (boluses + delivered−scheduled basal) or add an EGP term, treating scheduled basal as EGP-neutral. Re-tune constants + tests after. This is the single highest-ROI fix; every learned label inherits the baseline drift until it lands.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Insulin effect computed from net insulin or explicit EGP term
- [ ] #2 Constants re-tuned with tests
- [ ] #3 A well-tuned fasting user no longer reads as maximally insulin-resistant
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P0-2 (headline issue #1)
Effort: M
Where: predictor.dart:290-291, insulin_math.dart:107-145
Roadmap status: open
<!-- SECTION:NOTES:END -->
