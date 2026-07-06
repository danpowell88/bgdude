---
id: TASK-20
title: P2-4 Regularize/early-stop the GBM
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
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude's forecast is corrected by a "gradient-boosted" model (GBM) — a common machine-learning method that builds many small decision trees, each fixing the previous ones' mistakes. It currently trains a fixed number of trees with no brake, so it can "overfit": memorise quirks of the training data that don't generalise.

**Reason for change.** An overfit corrector looks great on paper but predicts worse in real life. Standard guardrails — stopping early when extra trees stop helping, and training each tree on a random subset — keep it honest. Folded into the walk-forward work (TASK-55).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 nEstimators chosen by early stopping on validation folds
- [ ] #2 Row/feature subsampling added to gbm.dart
- [ ] #3 No regression in held-out RMSE vs current model
- [ ] #4 Coordinated with TASK-55 (§4-1.10)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** In gbm.dart add validation-chosen nEstimators (early stopping on the held-out fold) + row/feature subsampling. Pick nEstimators on the §4-1.10 (TASK-55) folds.

**Testing.** Held-out RMSE no worse than current; early-stopping picks a sensible nEstimators on synthetic data. ML-honesty tests first (coverage + bias, synthetic-data recovery); `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P2-4 (in §4-1.10)
Effort: M
Roadmap status: open
<!-- SECTION:NOTES:END -->
