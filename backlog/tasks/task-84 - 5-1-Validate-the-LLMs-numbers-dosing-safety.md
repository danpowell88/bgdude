---
id: TASK-84
title: 5-1 Validate the LLM's numbers (dosing safety)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:47'
labels:
  - roadmap
  - §5
  - panel-scanner
  - "\U0001F9E0 llm"
  - "\U0001F512 safety"
dependencies: []
priority: high
ordinal: 84000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** When the on-device AI reads a nutrition label, it can occasionally return a nonsensical number (e.g. 900 g of carbs per 100 g). Those numbers can flow into carb dosing.

**Reason for change.** The highest-priority AI-safety fix: sanity-check every value in the parser (not by asking the AI nicely) — hard bounds per field and cross-checks (sugars can't exceed carbs, per-serving must match per-100g). Out-of-range values are dropped rather than trusted.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Hard per-field bounds → null on out-of-range
- [ ] #2 Cross-field checks (sugars≤carbs; per-serve consistency)
- [ ] #3 All-macros-empty rejection retained
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** In the parser (not the prompt): hard per-field bounds (macros 0–100 g/100g, sodium ≤5000 mg, energy ≤4000 kJ/100g, serving 1–1000 g, servings/pack 1–100 → out-of-range = null); cross-field checks (sugars ≤ carbs; per-serve ≈ per-100g×serving/100 within ~25% else keep per-100g + serving and null per-serve); keep the all-macros-empty rejection.

**Testing.** Unit tests per bound and cross-field rule against fixtures; out-of-range → null. Validation/grounding tests (bounds + OCR-grounding); degrade gracefully with no model; `flutter analyze`/`flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §5 item 1
Effort: S
Flags: 🧠 llm 🔒 safety
Roadmap status: open
<!-- SECTION:NOTES:END -->
