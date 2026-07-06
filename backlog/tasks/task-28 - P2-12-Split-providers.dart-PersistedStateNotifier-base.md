---
id: TASK-28
title: P2-12 Split providers.dart + PersistedStateNotifier base
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:27'
labels:
  - roadmap
  - §1-P2
  - phase-6
  - architecture
dependencies: []
priority: medium
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Split the 2,239-line providers.dart god-file and introduce a PersistedStateNotifier base. This is the anchor refactor — fully specified in §3.A / TASK-35; this P2-12 entry closes when TASK-35 lands.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P2-12 → §3.A
Effort: L
Roadmap status: open
<!-- SECTION:NOTES:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 providers.dart split into the §3.A target modules
- [ ] #2 PersistedStateNotifier<T> base with restore-then-save ordering
- [ ] #3 Detailed plan + migration steps in TASK-35 (§3.A)
<!-- AC:END -->
