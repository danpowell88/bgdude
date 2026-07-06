---
id: TASK-92
title: 6.1 Prediction validation on real data
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:27'
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
Once the pump link is live, run the accuracy screen against real history and tune momentum/IOB/COB params. Depends on P0-2 landing first (learned labels are poisoned until then).
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §6
Effort: M
Flags: 🔌 hardware
Roadmap status: open
<!-- SECTION:NOTES:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Accuracy screen run on >=2 weeks of real history
- [ ] #2 Momentum/IOB/COB params tuned to the real data
- [ ] #3 Before/after RMSE + Clarke recorded
<!-- AC:END -->
