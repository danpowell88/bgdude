---
id: TASK-85
title: 5-2 OCR-grounding check (anti-hallucination + injection guard)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
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
Accept an LLM value only if the number literally appears in the OCR text (± comma/rounding). Post-parse filter in PanelScanService so it applies to any model.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 LLM values accepted only if present in OCR text
- [ ] #2 Applied as a post-parse filter for any model
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §5 item 2
Effort: S
Flags: 🧠 llm 🔒 safety
Roadmap status: open
<!-- SECTION:NOTES:END -->
