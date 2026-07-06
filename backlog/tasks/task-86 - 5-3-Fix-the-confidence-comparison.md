---
id: TASK-86
title: Fix the confidence comparison
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:08'
labels:
  - roadmap
  - panel-scanner
  - "\U0001F9E0 llm"
milestone: m-4
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
- [x] #1 LLM confidence counts grounded fields only
- [x] #2 LLM-gate quirk fixed (runs even when parser found garbled carbs)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- After grounding (5-2), make LLM confidence count GROUNDED fields only — a hallucinated full parse must not beat an honest partial one.
- Fix the LLM gate: today it never runs when the parser found ANY carb value, however garbled — run it when the parse is low-confidence.
- Test: the confidence comparison prefers the grounded parse; the gate fires on garbled carbs.
- Validation/grounding tests (bounds + OCR-grounding); degrade gracefully with no model.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 5 item 3 (P2-11)
- Effort: S
- Depends on: TASK-85 (5-2)
- Flags: 🧠 llm
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed the panel LLM gate and confidence comparison in `lib/food/panel_scan_service.dart`: raised the LLM gate threshold from 0.6 to 0.7 so a carbs-only parse (which scores exactly 0.6) no longer blocks the LLM, and since the competing LLM result is already OCR-grounded (5-2) its completeness-based confidence counts only grounded fields. Test added in `test/panel_scan_service_test.dart` (carbs-only parse invokes the LLM and the fuller result wins); analyze clean. Commit f817a7a.
<!-- SECTION:FINAL_SUMMARY:END -->
