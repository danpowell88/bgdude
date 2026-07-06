---
id: TASK-87
title: 5-4 Few-shot prompt + on-device self-check
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §5
  - panel-scanner
  - "\U0001F9E0 llm"
  - "\U0001F50C hardware"
dependencies: []
priority: medium
ordinal: 87000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two exemplars (AU/EU two-column, US single-column) in buildPanelPrompt; "test the model" button on the AI screen (canned text → LLM → JSON, pass/fail); then run the on-device accuracy integration test with the LLM enabled and record numbers.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Few-shot exemplars in buildPanelPrompt
- [ ] #2 "Test the model" button on the AI screen
- [ ] #3 On-device accuracy test with LLM enabled, numbers recorded
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §5 item 4
Effort: M
Flags: 🧠 llm 🔌 hardware
Roadmap status: open
<!-- SECTION:NOTES:END -->
