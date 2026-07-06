---
id: TASK-26
title: 'P2-10 Clarke grid: optional Parkes/consensus grid'
status: In Progress
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
labels:
  - roadmap
  - §1-P2
  - ml
dependencies: []
priority: low
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** To grade forecast accuracy against actual outcomes, bgdude plots errors on a "Clarke error grid" — a clinical chart that sorts prediction errors by how dangerous they'd be. The "Parkes" (consensus) grid is a newer, more widely-accepted version of the same idea.

**Reason for change.** This is an optional modernisation: moving to the Parkes grid reflects current clinical consensus on which errors matter most.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Parkes/consensus grid zones implemented
- [ ] #2 Per-zone reference tests (as done for Clarke)
- [ ] #3 ModelAccuracyScreen uses/offers the chosen grid
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Implement Parkes/consensus zones alongside Clarke; ModelAccuracyScreen uses/offers the chosen grid. Reuse the existing zone reference-test pattern.

**Testing.** Per-zone reference tests (as already done for Clarke) against published boundary points. ML-honesty tests first (coverage + bias, synthetic-data recovery); `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §1 P2-10
- Effort: M
- Roadmap status: partial
<!-- SECTION:NOTES:END -->
