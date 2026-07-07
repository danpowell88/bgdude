---
id: TASK-29
title: Nutrition-label AI (Gemma) — verify on-device inference
status: To Do
assignee:
  - Claude
created_date: '2026-07-06 03:10'
updated_date: '2026-07-07 13:00'
labels:
  - roadmap
  - panel-scanner
  - "\U0001F50C hardware"
  - "\U0001F9E0 llm"
  - detail-needed
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

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-07 12:58
---
detail-needed (2026-07-07, hardware gate): AC#1 (verify inference on a real device with a real model) and AC#3/#4's real-world validation explicitly need 'on-device (hardware): prepare a build + run on the real device'. No physical Android phone with the model downloaded is available in this environment to run flutter_gemma inference against. Also genuinely blocked per its own Depends-on note: 'section 5 items 1-3' (LLM dosing-safety/anti-hallucination guards) must land first — worth checking whether TASK-84/85/86 (the section-5 items) are done before this can even start meaningfully. Left In Progress; this is real, scoped work waiting on both a prerequisite check and hardware access.
---

author: Claude
created: 2026-07-07 12:59
---
Follow-up: checked the section-5 prerequisite (TASK-84 dosing-safety validation, TASK-85 OCR anti-hallucination guard, TASK-86 confidence-comparison fix) — all three are Done. So the only remaining blocker is the hardware/on-device inference verification itself (AC#1), not an unmet prerequisite.
---
<!-- COMMENTS:END -->
