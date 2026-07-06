---
id: TASK-15
title: >-
  P1-8 Replace silent catch(_) with logged catches; do not advance _lastFired on
  failed urgent-low
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 04:53'
labels:
  - roadmap
  - §1-P1
  - architecture
  - logging
  - detail-needed
dependencies: []
priority: medium
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Across the codebase there are 43 places that catch an error and do nothing with it ("swallow" it), 33 of them in one file. Two of these hide real problems: a failed urgent-low alert still records itself as "fired" (which can stop the retry), and the startup routine doesn't note when one of its jobs fails.

**Reason for change.** Silently swallowed errors make real failures invisible in the field — including an urgent-low that failed to send, or a startup job that never runs. Errors that matter should be logged.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 No unlogged catch(_) in the swept paths
- [ ] #2 Failed urgent-low does not advance _lastFired
- [ ] #3 Per-job startup failures recorded
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Sweep providers.dart: a swallow is legal only if the op is optional AND it logs (via the §3.D app_log). Do not advance _lastFired on a failed urgent-low; make runStartup record per-job failures.

**Testing.** Unit test that a failed urgent-low leaves _lastFired unchanged (so it retries); assert startup records a failing job. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able). `flutter analyze` clean and `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §1 P1-8 / §3.D
- Effort: S
- Where: providers.dart throughout
- Roadmap status: open

detail-needed (2026-07-06, goal triage): The catch-sweep AC depends on the app_log ring buffer from 3.D (TASK-38) existing first; do the two behavioural fixes as part of that sweep.
<!-- SECTION:NOTES:END -->
