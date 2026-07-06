---
id: TASK-27
title: P2-11 Panel parser quirks + LLM-gate fix
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:43'
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
**Background.** bgdude can read a nutrition label with the phone camera to get carbs. The text parser trips over several real-label quirks — "%DV" daily-value columns, energy shown as combined kJ/kcal, European labels that list "Salt" instead of sodium, and servings given in millilitres. Separately, the optional AI reader never runs if the plain parser found any carb number at all, even a garbled one.

**Reason for change.** These quirks produce wrong macros, which drive carb dosing, and the gate bug stops the AI from rescuing a bad parse. Pairs with the AI-scanner tasks.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 %DV tokens excluded from parsing
- [ ] #2 kJ/kcal split; EU Salt->sodium; ml servings handled
- [ ] #3 LLM gate runs even when the parser found garbled carbs
- [ ] #4 Parser unit test per quirk
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** In the panel parser: exclude %DV tokens; split kJ/kcal; map EU "Salt … g" → sodium (×400); handle ml servings. Fix the LLM gate to run when the parser result is low-confidence even if a carb value exists.

**Testing.** A parser unit test per quirk against fixtures in test/data/nutrition_panels.json; test the LLM gate fires on garbled carbs. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able). `flutter analyze` clean and `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §1 P2-11 → §5
- Effort: M
- Flags: 🧠 llm
- Roadmap status: open
<!-- SECTION:NOTES:END -->
