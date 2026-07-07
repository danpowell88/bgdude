---
id: TASK-85
title: OCR-grounding check (anti-hallucination + injection guard)
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:08'
labels:
  - roadmap
  - panel-scanner
  - "\U0001F9E0 llm"
  - "\U0001F512 safety"
milestone: m-4
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
- [x] #1 LLM values accepted only if present in OCR text
- [x] #2 Applied as a post-parse filter for any model
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Post-parse filter in `PanelScanService` (applies to any model): accept an LLM value only if the number literally appears in the OCR text (± comma/rounding).
- This is both an anti-hallucination and a prompt-injection guard.
- Test: an LLM value absent from the OCR text is rejected; present-with-rounding is accepted.
- Validation/grounding tests (bounds + OCR-grounding); degrade gracefully with no model.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 5 item 2
- Effort: S
- Flags: 🧠 llm 🔒 safety
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added OCR-grounding to the panel post-pass in `lib/food/panel_llm.dart`: an LLM value is kept only if a matching number appears in the label text (± comma/rounding), skipped when there is no text; applied to the LLM output that can hallucinate carb numbers driving dosing. Tests in `test/panel_llm_test.dart`; verified analyze clean and full suite green (465 tests, 5 new across 5-1/5-2). Commit 2ec61da.
<!-- SECTION:FINAL_SUMMARY:END -->
