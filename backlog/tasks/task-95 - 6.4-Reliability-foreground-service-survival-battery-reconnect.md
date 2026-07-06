---
id: TASK-95
title: 'Reliability (foreground service survival, battery, reconnect)'
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 12:57'
labels:
  - roadmap
  - pump
  - reliability
  - "\U0001F50C hardware"
  - detail-needed
milestone: m-7
dependencies: []
priority: medium
ordinal: 105000
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
- Foreground-service survival (Doze/task-kill).
- Battery impact.
- Reconnect after device sleep.
- Crash-free multi-day runs.
- Pairs with the Phase 4 pump work (2-5).
- On-device (🔌): prepare a build + an exact manual test procedure → run on the real device → report → fix. Verify Doze survival, sleep-reconnect, a measured battery figure, a multi-day crash-free run.
- Verify: desk tests still green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 6
- Effort: M
- Flags: 🔌 hardware
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:30
---
detail-needed (2026-07-06, goal triage): Long-run reliability (Doze survival, sleep-reconnect, battery, multi-day crash-free) can only be verified on a real device over days.
---
<!-- COMMENTS:END -->
