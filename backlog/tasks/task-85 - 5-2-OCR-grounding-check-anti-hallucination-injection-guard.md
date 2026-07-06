---
id: TASK-85
title: 5-2 OCR-grounding check (anti-hallucination + injection guard)
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 04:34'
labels:
  - roadmap
  - §5
  - panel-scanner
  - "\U0001F9E0 llm"
  - "\U0001F512 safety"
dependencies: []
priority: high
ordinal: 85000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** A language model can "hallucinate" — confidently state a number that isn't on the label — and a malicious label could even try to trick it.

**Reason for change.** A grounding check accepts an AI-reported number only if that exact number actually appears in the text the camera read. It's both an anti-hallucination guard and a defence against prompt-injection, and it works for any model.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 LLM values accepted only if present in OCR text
- [ ] #2 Applied as a post-parse filter for any model
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Post-parse filter in PanelScanService (applies to any model): accept an LLM value only if the number literally appears in the OCR text (± comma/rounding). This is both an anti-hallucination and a prompt-injection guard.

**Testing.** Test that an LLM value absent from the OCR text is rejected; present-with-rounding is accepted. Validation/grounding tests (bounds + OCR-grounding); degrade gracefully with no model; `flutter analyze`/`flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §5 item 2
- Effort: S
- Flags: 🧠 llm 🔒 safety
- Roadmap status: open
<!-- SECTION:NOTES:END -->
