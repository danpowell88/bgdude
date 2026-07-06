---
id: TASK-90
title: 5-7 Deterministic column reconstruction
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:47'
labels:
  - roadmap
  - §5
  - panel-scanner
dependencies: []
priority: medium
ordinal: 90000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Nutrition labels often have two columns (per-serving and per-100g). The camera text-reader has the geometry to tell columns apart but currently throws it away, which merges the columns and confuses the parser.

**Reason for change.** Rebuilding the columns from the layout geometry fixes most merged-column labels without needing the AI at all, and cleans up several other parsing quirks along the way.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Column reconstruction from ML Kit geometry
- [ ] #2 Parser quirks: %DV excluded, kJ/kcal split, EU Salt, ml servings
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Use ML Kit's block/line geometry (currently discarded) to rebuild per-serve/per-100g columns before parsing — fixes most merged-column cases without the LLM. Plus parser quirks: exclude %DV tokens, split kJ/kcal, capture EU "Salt … g", ml servings.

**Testing.** Column-reconstruction test on multi-column fixtures; a parser test per quirk. Validation/grounding tests (bounds + OCR-grounding); degrade gracefully with no model; `flutter analyze`/`flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §5 item 7
Effort: M
Roadmap status: open
<!-- SECTION:NOTES:END -->
