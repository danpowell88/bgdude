---
id: TASK-31
title: 2-3 Garmin complication — implement the real publisher
status: In Progress
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §2
  - phase-4
  - garmin
  - "\U0001F50C hardware"
dependencies: []
priority: medium
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
3 products build/run in sim; mis-implemented complication removed. Implement the real publisher (resource-defined complication + updateComplication, gated on `has :Complications` per garmin/COMPLICATIONS.md); verify on-watch. Highest-leverage Garmin item.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Resource-defined complication + updateComplication
- [ ] #2 Gated on has :Complications
- [ ] #3 Verified on a real watch
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §2 item 2-3
Effort: M
Where: garmin/COMPLICATIONS.md
Flags: 🔌 hardware
Roadmap status: partial
<!-- SECTION:NOTES:END -->
