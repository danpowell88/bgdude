---
id: TASK-1
title: 'P0-1 Correction subtracts bolus-only (or net) IOB, not total incl. basal'
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
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Correction currently subtracts total IOB (including basal), under-dosing. Use `_iob.fromBoluses(...)` for the subtraction; keep full IOB only for forward prediction.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Correction uses bolus-only/net IOB for the subtraction
- [ ] #2 Forward prediction still uses full IOB
- [ ] #3 Regression test on a fasting scenario
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P0-1
Effort: S
Where: bolus_advisor.dart:191,293-294
Roadmap status: open
<!-- SECTION:NOTES:END -->
