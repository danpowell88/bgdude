---
id: TASK-92
title: 6.1 Prediction validation on real data
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:47'
labels:
  - roadmap
  - §6
  - ml
  - "\U0001F50C hardware"
dependencies: []
priority: medium
ordinal: 92000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude's prediction accuracy has only been checked against simulated data. Once it's reading a real pump, its accuracy screen can be run against genuine history.

**Reason for change.** Validating and tuning the forecast parameters on real data is how the predictions earn trust. It depends on the core model fix (P0-2) landing first, since the learned numbers are unreliable until then.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Accuracy screen run on >=2 weeks of real history
- [ ] #2 Momentum/IOB/COB params tuned to the real data
- [ ] #3 Before/after RMSE + Clarke recorded
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Once the pump link is live, run the accuracy screen against real history and tune momentum/IOB/COB params. Depends on P0-2 (labels are poisoned until then).

**Testing.** Run on ≥2 weeks of real history; record before/after RMSE + Clarke. On-device (🔌): prepare a build + an exact manual test procedure → run on the real device → report → fix. Desk tests still green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §6
Effort: M
Flags: 🔌 hardware
Roadmap status: open
<!-- SECTION:NOTES:END -->
