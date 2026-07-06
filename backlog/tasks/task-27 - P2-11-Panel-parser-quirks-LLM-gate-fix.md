---
id: TASK-27
title: P2-11 Panel parser quirks + LLM-gate fix
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:27'
labels:
  - roadmap
  - §1-P2
  - panel-scanner
  - "\U0001F9E0 llm"
dependencies: []
priority: medium
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Nutrition-panel parser robustness (see §5-1/2 and §5-7): exclude %DV tokens, split combined kJ/kcal energy, capture EU "Salt … g" -> sodium, and handle ml servings. Plus the LLM-gate fix: today the LLM never runs when the parser found ANY carb value, however garbled.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P2-11 → §5
Effort: M
Flags: 🧠 llm
Roadmap status: open
<!-- SECTION:NOTES:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 %DV tokens excluded from parsing
- [ ] #2 kJ/kcal split; EU Salt->sodium; ml servings handled
- [ ] #3 LLM gate runs even when the parser found garbled carbs
- [ ] #4 Parser unit test per quirk
<!-- AC:END -->
