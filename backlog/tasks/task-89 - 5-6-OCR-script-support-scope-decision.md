---
id: TASK-89
title: 5-6 OCR script support (scope decision)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:11'
labels:
  - roadmap
  - §5
  - panel-scanner
  - needs-exploration
dependencies: []
priority: low
ordinal: 89000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Latin-only OCR means CJK labels feed the LLM garbage. Either add script detection + ML Kit recognizers, or scope the copy honestly to Latin-script labels. Decide from real usage during 2-1.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §5 item 6
Effort: M
Depends on: 2-1
⚠ NEEDS MORE EXPLORATION: Scope decision, not just code: add CJK recognizers vs limit to Latin labels. Decide from real usage during 2-1.
<!-- SECTION:NOTES:END -->
