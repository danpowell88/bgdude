---
id: TASK-94
title: 6.3 Data integrity edges
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 05:30'
labels:
  - roadmap
  - §6
  - data-integrity
  - detail-needed
dependencies: []
priority: medium
ordinal: 94000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Real-world data has messy edges: gaps in the CGM stream, the noisy sensor warm-up period, a compression low, time-zone/daylight-saving shifts across your history, and a meter whose clock has drifted.

**Reason for change.** Handling these edges prevents corrupted statistics and misplaced events — the kind of subtle bugs that only show up on real data over time.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 CGM gaps handled without corrupting metrics
- [ ] #2 Warm-up/compression readings robustly excluded
- [ ] #3 Timezone/DST correct across historical data
- [ ] #4 Meter clock-skew detected and surfaced
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- CGM gap handling.
- Sensor warm-up/compression robustness.
- Timezone/DST across history.
- Meter clock-drift detection (`PumpSnapshot.fromJson` falls back to `DateTime.now()` with no skew detection).
- Unit tests per edge (gaps, warm-up, DST boundary, clock skew); add/extend under `test/`.
- Verify: `flutter analyze` clean, `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §6
- Effort: M
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:30
---
detail-needed (2026-07-06, goal triage): Data-integrity edges span several sub-fixes, some needing real-history verification (DST across history, meter clock drift); wants scoping into concrete sub-tickets.
---
<!-- COMMENTS:END -->
