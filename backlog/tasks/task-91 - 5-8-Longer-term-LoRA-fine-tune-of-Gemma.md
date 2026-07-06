---
id: TASK-91
title: '5-8 Longer-term: LoRA fine-tune of Gemma'
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:47'
labels:
  - roadmap
  - §5
  - panel-scanner
  - "\U0001F9E0 llm"
  - needs-exploration
dependencies: []
priority: low
ordinal: 91000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The general-purpose on-device AI is decent at labels but not specialised. "Fine-tuning" trains it further on example labels to make it better and possibly small enough to run faster.

**Reason for change.** This is a research spike: generate synthetic labels, fine-tune the model (a small 270M-parameter version versus the 1B baseline), and measure whether the accuracy/speed trade-off is worth it before committing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Spike: synthetic-panel generation from test/data/nutrition_panels.json
- [ ] #2 LoRA training pipeline evaluated (flutter_gemma installModel LoRA)
- [ ] #3 On-device eval: fine-tuned 270M vs 1B baseline (accuracy + latency)
- [ ] #4 Documented go/no-go before productionising
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Spike: generate synthetic panels from test/data/nutrition_panels.json; LoRA fine-tune Gemma (flutter_gemma supports LoRA in installModel); evaluate a fine-tuned 270M vs the 1B baseline for accuracy + latency on the Pixel; record a go/no-go.

**Testing.** Offline eval harness comparing models on the synthetic corpus; documented decision. Validation/grounding tests (bounds + OCR-grounding); degrade gracefully with no model; `flutter analyze`/`flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §5 item 8
- Effort: L
- Flags: 🧠 llm
- ⚠ NEEDS MORE EXPLORATION: Research spike: synthetic-panel generation + LoRA training pipeline + on-device eval of a 270M vs 1B model. Unproven; scope before committing.
<!-- SECTION:NOTES:END -->
