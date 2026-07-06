---
id: TASK-13
title: P1-6 Surface DB-open failure instead of silent in-memory swap
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §1-P1
  - phase-0
  - data-integrity
dependencies: []
priority: high
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
On DB-open failure the app silently swaps to an in-memory DB. Surface it (banner + log) instead.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 DB-open failure shows a banner
- [ ] #2 Failure is logged
- [ ] #3 No silent in-memory fallback
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P1-6
Effort: S
Where: main.dart:26-34
Roadmap status: open
<!-- SECTION:NOTES:END -->
