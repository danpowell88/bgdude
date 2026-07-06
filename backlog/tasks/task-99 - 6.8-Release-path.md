---
id: TASK-99
title: 6.8 Release path
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 04:52'
labels:
  - roadmap
  - §6
  - infra
  - "\U0001F50C hardware"
  - needs-exploration
  - detail-needed
dependencies: []
priority: low
ordinal: 99000
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
**Technical notes.** Configure a real signing keystore (replaces the debug signing currently used for release); decide distribution — Google Play internal-testing track vs sideload-only APK; verify a release build installs and runs.

**Testing.** Release build installs + runs on a real device; decision documented. On-device (🔌): prepare a build + an exact manual test procedure → run on the real device → report → fix. Desk tests still green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §6
- Effort: M
- Flags: 🔌 hardware
- ⚠ NEEDS MORE EXPLORATION: Decide distribution (Play internal track vs sideload-only) and set up real signing — a product/release decision.

detail-needed (2026-07-06, goal triage): Decision: distribution (Play internal track vs sideload) + a real signing keystore to set up.
<!-- SECTION:NOTES:END -->
