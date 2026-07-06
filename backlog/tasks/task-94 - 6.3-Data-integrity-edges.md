---
id: TASK-94
title: 6.3 Data integrity edges
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:27'
labels:
  - roadmap
  - §6
  - data-integrity
dependencies: []
priority: medium
ordinal: 94000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Edge-case hardening: CGM gap handling, sensor warm-up/compression robustness, timezone/DST across history, and meter clock drift (PumpSnapshot.fromJson currently falls back to DateTime.now() with no skew detection).
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §6
Effort: M
Roadmap status: open
<!-- SECTION:NOTES:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 CGM gaps handled without corrupting metrics
- [ ] #2 Warm-up/compression readings robustly excluded
- [ ] #3 Timezone/DST correct across historical data
- [ ] #4 Meter clock-skew detected and surfaced
<!-- AC:END -->
