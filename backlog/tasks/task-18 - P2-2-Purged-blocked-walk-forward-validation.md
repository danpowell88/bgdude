---
id: TASK-18
title: Purged/blocked walk-forward validation
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:10'
labels:
  - roadmap
  - ml
  - detail-needed
milestone: m-5
dependencies:
  - TASK-55
priority: medium
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** To decide whether a newly-trained prediction model is better than the old one, bgdude tests it on data it wasn't trained on. Today it uses one simple "train on the first part, test on the last part" split. Because glucose readings minutes apart are highly related, that single split can flatter a model that has really just memorised.

**Reason for change.** A misleading test can promote a worse model into daily use. A more rigorous scheme (several rolling test windows with a gap to prevent leakage) gives an honest verdict. Fully specified in the walk-forward-validation task (TASK-55).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Single time-split replaced by blocked walk-forward folds
- [ ] #2 Purge gap >= maxHorizon between train and test
- [ ] #3 Promotion decided on pooled fold metrics
- [ ] #4 Detailed implementation tracked in TASK-55 (section 4-1.10)
<!-- AC:END -->



## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- K=3–4 contiguous blocked folds with a purge gap ≥ `maxHorizon` (the ±6 min label slop makes the gap mandatory).
- Pooled fold metrics gate promotion.
- Final model retrains on everything.
- <~10 days of data falls back to the single split.
- Tests: purge-gap leakage assertion (no train row within `maxHorizon` of a test label); pooled-gate test. Detailed in TASK-55. ML-honesty tests first (coverage + bias, synthetic-data recovery).
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1, P2-2 → TASK-55 (section 4-1.10)
- Effort: M
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:28
---
detail-needed (2026-07-06, goal triage): Delivered by TASK-55 (§4-1.10); blocked on P0-2.
---
<!-- COMMENTS:END -->
