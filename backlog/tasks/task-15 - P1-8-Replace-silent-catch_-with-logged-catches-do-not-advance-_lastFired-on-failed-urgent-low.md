---
id: TASK-15
title: >-
  Replace silent catch(_) with logged catches; do not advance _lastFired on
  failed urgent-low
status: Done
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 14:47'
labels:
  - roadmap
  - architecture
  - logging
  - detail-needed
milestone: m-6
dependencies: []
priority: medium
ordinal: 103100
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** Across the codebase there are 43 places that catch an error and do nothing with it ("swallow" it), 33 of them in one file. Two of these hide real problems: a failed urgent-low alert still records itself as "fired" (which can stop the retry), and the startup routine doesn't note when one of its jobs fails.

**Reason for change.** Silently swallowed errors make real failures invisible in the field — including an urgent-low that failed to send, or a startup job that never runs. Errors that matter should be logged.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 No unlogged catch(_) in the swept paths
- [x] #2 Failed urgent-low does not advance _lastFired
- [x] #3 Per-job startup failures recorded
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Sweep `providers.dart`: a swallow is legal only if the op is optional AND it logs (via the TASK-38 `app_log`).
- Do not advance `_lastFired` on a failed urgent-low.
- Make `runStartup` record per-job failures.
- Unit test that a failed urgent-low leaves `_lastFired` unchanged (so it retries); assert startup records a failing job. Add/extend unit tests under `test/` (pure analytics/ml is `dart test`-able).
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 1, P1-8 / TASK-38 (section 3.D)
- Effort: S
- Where: `providers.dart` throughout
- Roadmap status: open

Resolved by TASK-38, which superset this ticket: (AC#2) the urgent-low path now records the fire only after a successful send (_coolPassed + _markFired) so a failed send retries; (AC#3) runStartup logs each job failure via appLog; (AC#1) the swept alert-send + startup catches now log via the new lib/logging/app_log.dart instead of swallowing. See commit e87be9f.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:27
---
detail-needed (2026-07-06, goal triage): The catch-sweep AC depends on the app_log ring buffer from 3.D (TASK-38) existing first; do the two behavioural fixes as part of that sweep.
---
<!-- COMMENTS:END -->
