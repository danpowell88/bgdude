---
id: TASK-22
title: P2-6 Dead constant sensitivity feature removed
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
labels:
  - roadmap
  - §1-P2
  - ml
dependencies: []
priority: low
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The forecast model is fed a list of input "features". One of them was a constant that never changed, so it carried no information.

**Reason for change.** DONE (July 2026): the dead feature was removed (feature set v4) — it was just noise/weight in the model.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Feature removed; feature version bumped to v4.

**Testing.** Covered by the feature-version tests. ML-honesty tests first (coverage + bias, synthetic-data recovery); `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P2-6
Effort: S
Roadmap status: done ✅
<!-- SECTION:NOTES:END -->
