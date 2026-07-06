---
id: TASK-18
title: P2-2 Purged/blocked walk-forward validation
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:27'
labels:
  - roadmap
  - §1-P2
  - phase-5
  - ml
dependencies: []
priority: medium
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replace the single chronological train/test split with purged, blocked walk-forward validation so promotion reflects out-of-sample skill. Fully specified in §4-1.10 / TASK-55 (K=3–4 contiguous folds, purge gap = maxHorizon, pooled metrics gate promotion).
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P2-2 → §4-1.10
Effort: M
Roadmap status: open
<!-- SECTION:NOTES:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Single time-split replaced by blocked walk-forward folds
- [ ] #2 Purge gap >= maxHorizon between train and test
- [ ] #3 Promotion decided on pooled fold metrics
- [ ] #4 Detailed implementation tracked in TASK-55 (§4-1.10)
<!-- AC:END -->
