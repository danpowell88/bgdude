---
id: TASK-20
title: P2-4 Regularize/early-stop the GBM
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
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Prevent GBM overfit: validation-chosen nEstimators (early stopping) + row/feature subsampling. Folded into the §4-1.10 / TASK-55 fold work so nEstimators is picked on held-out folds.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P2-4 (in §4-1.10)
Effort: M
Roadmap status: open
<!-- SECTION:NOTES:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 nEstimators chosen by early stopping on validation folds
- [ ] #2 Row/feature subsampling added to gbm.dart
- [ ] #3 No regression in held-out RMSE vs current model
- [ ] #4 Coordinated with TASK-55 (§4-1.10)
<!-- AC:END -->
