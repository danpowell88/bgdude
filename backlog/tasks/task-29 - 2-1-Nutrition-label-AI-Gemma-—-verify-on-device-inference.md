---
id: TASK-29
title: Nutrition-label AI (Gemma) — verify on-device inference
status: In Progress
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 12:58'
labels:
  - roadmap
  - panel-scanner
  - "\U0001F50C hardware"
  - "\U0001F9E0 llm"
milestone: m-4
dependencies: []
priority: medium
ordinal: 500100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude can read a nutrition label with the phone camera. For hard labels it can fall back to a small AI language model that runs entirely on the phone (Google's "Gemma", via the flutter_gemma library). The plumbing is built and the app launches, but the AI has never actually been run against a real model on a real phone.

**Reason for change.** Until it is proven on-device, the AI label-reading is capability that exists on paper only. It must wait behind the safety checks (section 5 items 1–3) that stop the AI inventing numbers, since its output influences carb dosing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Inference verified on a real device with a real model
- [ ] #2 Known-good Gemma 3 1B .task URL + licence flow
- [ ] #3 Auto-suggest download on scan failure
- [ ] #4 RAM/space gating
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Curate a known-good Gemma 3 1B `.task` URL + licence flow.
- Verify inference on the Pixel.
- Auto-suggest download on scan failure.
- Add RAM/space gating (→ TASK-88).
- Evaluate a fine-tuned Gemma 3 270M (→ TASK-91).
- Test: on-device accuracy integration test with the LLM enabled; record numbers. Verify graceful degradation when no model/insufficient RAM.
- On-device (hardware): prepare a build + an exact manual test procedure → run on the real device → report → fix.
- Verify: desk tests still green — `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 2 item 2-1
- Effort: M
- Depends on: section 5 items 1–3 land first
- Flags: 🔌 hardware 🧠 llm
- Roadmap status: partial
<!-- SECTION:NOTES:END -->
