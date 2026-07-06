---
id: TASK-99
title: Release path
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 12:58'
labels:
  - roadmap
  - infra
  - "\U0001F50C hardware"
  - needs-exploration
  - detail-needed
milestone: m-7
dependencies: []
priority: low
ordinal: 501200
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude currently builds using the throwaway "debug" signing key, and there's no decision on how it would actually be distributed.

**Reason for change.** A real release needs a proper signing key and a distribution choice (Google Play's internal-testing track versus simply sideloading the APK). This is a product/release decision plus the signing setup.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Distribution decided: Play internal track vs sideload-only
- [ ] #2 Real signing keystore configured (replaces debug signing)
- [ ] #3 Release build verified: installs + runs on a real device
- [ ] #4 Decision + steps documented
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Configure a real signing keystore (replaces the debug signing currently used for release).
- Decide distribution — Google Play internal-testing track vs sideload-only APK.
- Verify a release build installs and runs.
- Testing: release build installs + runs on a real device; decision documented.
- On-device (🔌): prepare a build + an exact manual test procedure → run on the real device → report → fix. Desk tests still green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 6
- Effort: M
- Flags: 🔌 hardware
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:24
---
⚠ NEEDS MORE EXPLORATION: Decide distribution (Play internal track vs sideload-only) and set up real signing — a product/release decision.
---

author: Claude
created: 2026-07-06 05:24
---
detail-needed (2026-07-06, goal triage): Decision: distribution (Play internal track vs sideload) + a real signing keystore to set up.
---
<!-- COMMENTS:END -->
