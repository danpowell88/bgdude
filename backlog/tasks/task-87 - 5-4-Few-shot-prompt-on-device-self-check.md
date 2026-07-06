---
id: TASK-87
title: Few-shot prompt + on-device self-check
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 12:58'
labels:
  - roadmap
  - panel-scanner
  - "\U0001F9E0 llm"
  - "\U0001F50C hardware"
  - detail-needed
milestone: m-4
dependencies: []
priority: medium
ordinal: 500500
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** The AI does better with a couple of worked examples in its prompt, and there's no quick way to check the model is working on a device.

**Reason for change.** Adding two example labels to the prompt (a two-column European style and a single-column US style) improves accuracy, and a "test the model" button gives a fast on-device sanity check. Then measure real accuracy with the AI enabled.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Few-shot exemplars in buildPanelPrompt
- [ ] #2 "Test the model" button on the AI screen
- [ ] #3 On-device accuracy test with LLM enabled, numbers recorded
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add two few-shot exemplars in `buildPanelPrompt` (AU/EU two-column, US single-column).
- Add a "test the model" button on the AI screen (canned text → LLM → JSON, pass/fail).
- Run the on-device accuracy integration test with the LLM enabled and record numbers.
- Prompt-format test; on-device self-check button; record accuracy numbers.
- Validation/grounding tests (bounds + OCR-grounding); degrade gracefully with no model.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 5 item 4
- Effort: M
- Flags: 🧠 llm 🔌 hardware
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:28
---
detail-needed (2026-07-06, goal triage): Few-shot prompt + on-device self-check needs a real Gemma model on a device to run and record accuracy.
---
<!-- COMMENTS:END -->
