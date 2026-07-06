---
id: TASK-5
title: P0-5 Rescue-carb calc uses bolus-only IOB
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §1-P0
  - phase-0
  - dosing-math
dependencies: []
priority: high
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Rescue-carb calculation must use bolus-only IOB so phantom basal IOB does not over-treat lows.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Rescue carbs computed from bolus-only IOB
- [ ] #2 Test: phantom basal no longer inflates rescue carbs
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P0-5
Effort: S
Where: rescue_carbs.dart:56
Roadmap status: open
<!-- SECTION:NOTES:END -->
