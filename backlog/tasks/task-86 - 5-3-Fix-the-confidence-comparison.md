---
id: TASK-86
title: 5-3 Fix the confidence comparison
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:47'
labels:
  - roadmap
  - §5
  - panel-scanner
  - "\U0001F9E0 llm"
dependencies: []
priority: medium
ordinal: 86000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude scores how confident a label reading is by how complete it is. That lets a model which invented a full set of numbers score higher than an honest reading that only found a couple. Also, the AI never runs at all if the plain text-parser found any carb value, even a garbled one.

**Reason for change.** After the grounding check, confidence should count only grounded (verified) fields, so honesty beats fabrication; and the AI should be allowed to rescue a low-confidence parse instead of being blocked by a garbled number.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 LLM confidence counts grounded fields only
- [ ] #2 LLM-gate quirk fixed (runs even when parser found garbled carbs)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** After grounding (5-2), LLM confidence counts GROUNDED fields only (a hallucinated full parse must not beat an honest partial one). Fix the LLM gate: today it never runs when the parser found ANY carb value, however garbled — run it when the parse is low-confidence.

**Testing.** Test the confidence comparison prefers the grounded parse; test the gate fires on garbled carbs. Validation/grounding tests (bounds + OCR-grounding); degrade gracefully with no model; `flutter analyze`/`flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §5 item 3 (P2-11)
- Effort: S
- Depends on: 5-2
- Flags: 🧠 llm
- Roadmap status: open
<!-- SECTION:NOTES:END -->
