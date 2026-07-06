---
id: TASK-16
title: 'Model-download security (reject HTTP, host allowlist, SHA-256, no token echo)'
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 12:57'
labels:
  - roadmap
  - security
  - "\U0001F9E0 llm"
  - detail-needed
milestone: m-4
dependencies: []
priority: medium
ordinal: 103200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude can download an optional on-device AI model to read tricky nutrition labels. The downloader currently accepts insecure HTTP, isn't careful about where it sends access tokens, doesn't check the downloaded file is genuine, and can print the URL/token into logs.

**Reason for change.** A tampered or intercepted model file runs on your phone and drives label-reading that feeds carb dosing; a leaked token is a credential exposure. The download needs to be locked down (HTTPS-only, trusted hosts, integrity check).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 HTTP rejected
- [ ] #2 Token only to allowlisted hosts
- [ ] #3 SHA-256 verification
- [ ] #4 URL/token never logged
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- In `panel_model_manager.dart` / `ai_model_screen.dart`: reject non-HTTPS.
- Send the token only to allowlisted HF/Kaggle hosts.
- SHA-256 verify the downloaded file against a pinned hash.
- Never log URL/token.
- Unit tests: HTTP rejected; token withheld from non-allowlisted host; wrong SHA-256 rejected; assert no URL/token in log output. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able).
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1, P1-9 (overlaps TASK-88, section 5-5)
- Effort: S–M
- Where: `panel_model_manager.dart`, `ai_model_screen.dart`
- Flags: 🧠 llm
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:28
---
detail-needed (2026-07-06, goal triage): Needs the concrete model-host allowlist decision (HF/Kaggle exact hosts) + a known-good model URL and its published SHA-256 to verify the integrity flow end-to-end.
---
<!-- COMMENTS:END -->
