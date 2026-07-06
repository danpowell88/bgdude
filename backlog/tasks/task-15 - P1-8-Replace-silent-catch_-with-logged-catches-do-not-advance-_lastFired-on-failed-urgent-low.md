---
id: TASK-15
title: >-
  P1-8 Replace silent catch(_) with logged catches; do not advance _lastFired on
  failed urgent-low
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §1-P1
  - architecture
  - logging
dependencies: []
priority: medium
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replace bare catch(_){} with logged catches. Two behavioural fixes: a failed urgent-low must not advance _lastFired; runStartup records per-job failures. See §3.D.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 No unlogged catch(_) in the swept paths
- [ ] #2 Failed urgent-low does not advance _lastFired
- [ ] #3 Per-job startup failures recorded
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §1 P1-8 / §3.D
Effort: S
Where: providers.dart throughout
Roadmap status: open
<!-- SECTION:NOTES:END -->
