---
id: TASK-6
title: P0-6 Advisor hard low-guard on current reading + compression-low exclusion
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §1-P0
  - phase-0
  - dosing-math
  - "\U0001F512 safety"
dependencies: []
priority: high
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Advisor should hard-guard on the current reading ("treat the low first") and exclude compression lows.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Advisor blocks/warns before dosing into a current low
- [ ] #2 Compression-low readings excluded from the guard
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P0-6
Effort: S
Where: bolus_advisor.dart:183
Flags: 🔒 safety
Roadmap status: open
<!-- SECTION:NOTES:END -->
