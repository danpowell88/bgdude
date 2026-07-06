---
id: TASK-95
title: '6.4 Reliability (foreground service survival, battery, reconnect)'
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:27'
labels:
  - roadmap
  - §6
  - pump
  - reliability
  - "\U0001F50C hardware"
dependencies: []
priority: medium
ordinal: 95000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Long-run reliability on real hardware: foreground-service survival, battery impact, reconnect after device sleep, and crash-free multi-day runs. Pairs with Phase 4 pump work (2-5).
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
- [ ] #1 Foreground service survives Doze / task-kill
- [ ] #2 Reconnects after device sleep
- [ ] #3 Battery impact measured and acceptable
- [ ] #4 Multi-day crash-free run verified
<!-- AC:END -->
