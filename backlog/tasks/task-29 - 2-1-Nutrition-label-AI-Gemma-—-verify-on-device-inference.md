---
id: TASK-29
title: 2-1 Nutrition-label AI (Gemma) — verify on-device inference
status: In Progress
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §2
  - phase-4
  - panel-scanner
  - "\U0001F50C hardware"
  - "\U0001F9E0 llm"
dependencies: []
priority: medium
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Runtime wired (flutter_gemma on AGP 8.9), download/manage UI, gated fallback, builds+launches. Remaining: verify inference on a real device with a real model; curate a known-good Gemma 3 1B .task URL + licence flow; auto-suggest download on scan failure; RAM/space gating (→ §5-5); consider fine-tuned Gemma 3 270M (→ §5-8).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Inference verified on a real device with a real model
- [ ] #2 Known-good Gemma 3 1B .task URL + licence flow
- [ ] #3 Auto-suggest download on scan failure
- [ ] #4 RAM/space gating
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §2 item 2-1
Effort: M
Depends on: §5 items 1–3 land first
Flags: 🔌 hardware 🧠 llm
Roadmap status: partial
<!-- SECTION:NOTES:END -->
