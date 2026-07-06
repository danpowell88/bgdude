---
id: TASK-20
title: Regularize/early-stop the GBM
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 12:57'
labels:
  - roadmap
  - ml
  - detail-needed
milestone: m-5
dependencies:
  - TASK-55
priority: medium
ordinal: 103500
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
- [ ] #4 Coordinated with TASK-55
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- In `gbm.dart`, add validation-chosen `nEstimators` using early stopping on the held-out fold.
- Add row/feature subsampling to `gbm.dart`.
- Pick `nEstimators` on the TASK-55 folds.
- Run ML-honesty tests first (coverage + bias, synthetic-data recovery).
- Test: held-out RMSE no worse than current; early stopping picks a sensible `nEstimators` on synthetic data.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1 P2-4 (in TASK-55)
- Effort: M
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:23
---
detail-needed (2026-07-06, goal triage): Delivered by TASK-55 (§4-1.10); blocked on P0-2.
---
<!-- COMMENTS:END -->
