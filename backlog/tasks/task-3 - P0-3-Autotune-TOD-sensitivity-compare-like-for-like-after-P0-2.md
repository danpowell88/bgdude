---
id: TASK-3
title: P0-3 Autotune & TOD sensitivity compare like-for-like (after P0-2)
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
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
After P0-2, Autotune and time-of-day sensitivity must compare like-for-like — a well-tuned fasting user must score ≈1.0. Largely falls out of P0-2.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Fasting well-tuned user scores ≈1.0 in Autotune
- [ ] #2 TOD sensitivity consistent with net-insulin model
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P0-3
Effort: M (falls out of P0-2)
Where: autotune.dart, time_of_day_sensitivity.dart
Depends on: P0-2
Roadmap status: open
<!-- SECTION:NOTES:END -->
