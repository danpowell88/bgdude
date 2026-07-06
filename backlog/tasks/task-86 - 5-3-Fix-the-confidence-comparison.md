---
id: TASK-86
title: 5-3 Fix the confidence comparison
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
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
Completeness-scored confidence lets a hallucinating model beat an honest partial parse at 0.9. After item 2, LLM confidence counts grounded fields only. Also fix the LLM-gate quirk (P2-11): today the LLM never runs when the parser found any carb value, however garbled.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 LLM confidence counts grounded fields only
- [ ] #2 LLM-gate quirk fixed (runs even when parser found garbled carbs)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §5 item 3 (P2-11)
Effort: S
Depends on: 5-2
Flags: 🧠 llm
Roadmap status: open
<!-- SECTION:NOTES:END -->
