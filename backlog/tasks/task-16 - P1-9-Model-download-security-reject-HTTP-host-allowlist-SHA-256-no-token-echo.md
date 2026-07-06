---
id: TASK-16
title: >-
  P1-9 Model-download security (reject HTTP, host allowlist, SHA-256, no token
  echo)
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §1-P1
  - security
  - "\U0001F9E0 llm"
dependencies: []
priority: medium
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Reject HTTP, send tokens only to HF/Kaggle hosts, SHA-256 verify downloads, and never echo URL/token. Overlaps §5-5.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 HTTP rejected
- [ ] #2 Token only to allowlisted hosts
- [ ] #3 SHA-256 verification
- [ ] #4 URL/token never logged
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P1-9 (overlaps §5-5)
Effort: S–M
Where: panel_model_manager.dart, ai_model_screen.dart
Flags: 🧠 llm
Roadmap status: open
<!-- SECTION:NOTES:END -->
