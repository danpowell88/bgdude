---
id: TASK-90
title: 5-7 Deterministic column reconstruction
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
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
Use ML Kit's block/line geometry (currently discarded) to rebuild per-serve/per-100g columns before parsing — fixes most merged-column cases without the LLM. Plus parser quirks: exclude %DV tokens, split kJ/kcal, capture EU "Salt … g", ml servings.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Column reconstruction from ML Kit geometry
- [ ] #2 Parser quirks: %DV excluded, kJ/kcal split, EU Salt, ml servings
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §5 item 7
Effort: M
Roadmap status: open
<!-- SECTION:NOTES:END -->
