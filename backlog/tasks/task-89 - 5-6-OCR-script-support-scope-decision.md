---
id: TASK-89
title: 5-6 OCR script support (scope decision)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:47'
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
**Background.** The label text-reader only handles Latin scripts, so a Chinese/Japanese/Korean label feeds the AI garbage.

**Reason for change.** This is a scope decision: either add script detection and the extra recognizers, or honestly state in the app that only Latin-script labels are supported. The choice should be informed by real usage during the Gemma verification.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Decision recorded: add CJK/script recognizers vs scope to Latin-script labels
- [ ] #2 If scoped: user-facing copy states Latin-only support
- [ ] #3 If extended: ML Kit script detection + recognizer wiring
- [ ] #4 Decision informed by real usage during 2-1
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Latin-only OCR feeds CJK labels as garbage to the LLM. Decide: add ML Kit script detection + the relevant recognizers, OR scope the copy honestly to Latin-script labels. Inform the decision with real usage during item 2-1.

**Testing.** If extended: script-detection unit test. If scoped: the guide/copy states Latin-only. Validation/grounding tests (bounds + OCR-grounding); degrade gracefully with no model; `flutter analyze`/`flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §5 item 6
Effort: M
Depends on: 2-1
⚠ NEEDS MORE EXPLORATION: Scope decision, not just code: add CJK recognizers vs limit to Latin labels. Decide from real usage during 2-1.
<!-- SECTION:NOTES:END -->
