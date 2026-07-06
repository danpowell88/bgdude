---
id: TASK-90
title: Deterministic column reconstruction
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 16:09'
labels:
  - roadmap
  - panel-scanner
  - detail-needed
milestone: m-4
dependencies: []
priority: medium
ordinal: 500700
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Nutrition labels often have two columns (per-serving and per-100g). The camera text-reader has the geometry to tell columns apart but currently throws it away, which merges the columns and confuses the parser.

**Reason for change.** Rebuilding the columns from the layout geometry fixes most merged-column labels without needing the AI at all, and cleans up several other parsing quirks along the way.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Column reconstruction from ML Kit geometry
- [x] #2 Parser quirks: %DV excluded, kJ/kcal split, EU Salt, ml servings
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Use ML Kit block/line geometry (currently discarded) to rebuild per-serve/per-100g columns before parsing — fixes most merged-column cases without the LLM.
- Fix parser quirks: exclude %DV tokens, split kJ/kcal, capture EU "Salt … g", ml servings.
- Column-reconstruction test on multi-column fixtures; a parser test per quirk.
- Validation/grounding tests (bounds + OCR-grounding); degrade gracefully with no model.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 5 item 7
- Effort: M
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:29
---
detail-needed (2026-07-06, goal triage): Column reconstruction needs ML Kit block/line geometry plumbed through the OCR pipeline (currently discarded) — a medium OCR-pipeline change; confirm scope.
---

author: Claude
created: 2026-07-06 16:09
---
AC#2 (parser quirks: %DV excluded, kJ/kcal split, EU salt→sodium, ml servings) is already delivered by TASK-27 — see nutrition_panel_parser.dart (_energy prefers kJ w/ kcal×4.184 fallback, _sodium salt×400, _numbersOn %DV skip, _servingQty accepts ml, two-column 'per 100 g/ml' detection). AC#1 (column reconstruction from ML Kit geometry) is NOT done and is a substantial OCR-layer change: the PanelOcr interface returns only merged text (readText → String), discarding the bounding boxes ML Kit provides. Doing it needs (a) exposing per-line geometry from MlKitPanelOcr (result.blocks/lines .boundingBox), (b) a pure column-reconstruction pass grouping lines by x-cluster before parsing, (c) integrating without regressing the existing text-based twoColumn heuristic, and (d) verification against the real-label OCR accuracy suite (integration_test/nutrition_ocr_accuracy_test, which pulls OpenFoodFacts images + needs an emulator). Best done focused with that verification loop rather than blind. The pure reconstruction fn is unit-testable with synthetic geometry once the interface exposes it.
---
<!-- COMMENTS:END -->
