---
id: TASK-95
title: '6.4 Reliability (foreground service survival, battery, reconnect)'
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:47'
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
**Background.** For a companion app to be trustworthy it has to keep running reliably in the background for days — surviving Android's battery-saving, reconnecting after the phone sleeps, without draining the battery or crashing.

**Reason for change.** This is the long-run reliability pass on real hardware that turns a working demo into a dependable daily driver. Goes with the pump reliability work.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Foreground service survives Doze / task-kill
- [ ] #2 Reconnects after device sleep
- [ ] #3 Battery impact measured and acceptable
- [ ] #4 Multi-day crash-free run verified
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Foreground-service survival (Doze/task-kill), battery impact, reconnect after device sleep, crash-free multi-day runs. Pairs with the Phase 4 pump work (2-5).

**Testing.** On-device: Doze survival, sleep-reconnect, a measured battery figure, a multi-day crash-free run. On-device (🔌): prepare a build + an exact manual test procedure → run on the real device → report → fix. Desk tests still green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §6
- Effort: M
- Flags: 🔌 hardware
- Roadmap status: open
<!-- SECTION:NOTES:END -->
