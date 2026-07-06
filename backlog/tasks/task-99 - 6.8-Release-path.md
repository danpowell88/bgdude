---
id: TASK-99
title: 6.8 Release path
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:28'
labels:
  - roadmap
  - §6
  - infra
  - "\U0001F50C hardware"
  - needs-exploration
dependencies: []
priority: low
ordinal: 99000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Establish a real release path: replace debug signing with a proper keystore/signing config, then decide distribution — Google Play internal-testing track vs sideload-only APK — and verify a release build installs and runs on a real device. This is a product/release decision, not just a build change.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Distribution decided: Play internal track vs sideload-only
- [ ] #2 Real signing keystore configured (replaces debug signing)
- [ ] #3 Release build verified: installs + runs on a real device
- [ ] #4 Decision + steps documented
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §6
Effort: M
Flags: 🔌 hardware
⚠ NEEDS MORE EXPLORATION: Decide distribution (Play internal track vs sideload-only) and set up real signing — a product/release decision.
<!-- SECTION:NOTES:END -->
