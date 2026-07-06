---
id: TASK-18
title: P2-2 Purged/blocked walk-forward validation
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
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
**Background.** To decide whether a newly-trained prediction model is better than the old one, bgdude tests it on data it wasn't trained on. Today it uses one simple "train on the first part, test on the last part" split. Because glucose readings minutes apart are highly related, that single split can flatter a model that has really just memorised.

**Reason for change.** A misleading test can promote a worse model into daily use. A more rigorous scheme (several rolling test windows with a gap to prevent leakage) gives an honest verdict. Fully specified in the walk-forward-validation task (TASK-55).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Single time-split replaced by blocked walk-forward folds
- [ ] #2 Purge gap >= maxHorizon between train and test
- [ ] #3 Promotion decided on pooled fold metrics
- [ ] #4 Detailed implementation tracked in TASK-55 (§4-1.10)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** K=3–4 contiguous blocked folds with a purge gap ≥ maxHorizon (the ±6 min label slop makes the gap mandatory); pooled fold metrics gate promotion; final model retrains on everything; <~10 days falls back to the single split.

**Testing.** Purge-gap leakage assertion (no train row within maxHorizon of a test label); pooled-gate test. Detailed in TASK-55. ML-honesty tests first (coverage + bias, synthetic-data recovery); `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §1 P2-2 → §4-1.10
- Effort: M
- Roadmap status: open
<!-- SECTION:NOTES:END -->
