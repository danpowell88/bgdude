---
id: TASK-38
title: 3.D Error-handling & logging discipline + on-device log ring buffer
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 05:29'
labels:
  - roadmap
  - §3
  - architecture
  - logging
  - detail-needed
dependencies: []
priority: medium
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** There are 43 spots in the code that catch an error and do nothing with it, and there's no on-device log to see what went wrong in the field.

**Reason for change.** Errors that vanish silently make real problems invisible on a user's phone. Adding a small on-device log (the "developer console" infra) and only allowing an error to be ignored if it's optional and logged makes failures visible.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 app_log.dart ring buffer (~500 entries, no network)
- [ ] #2 Surfaced read-only in the Developer/Advanced screen
- [ ] #3 Swept catches log or are removed
- [ ] #4 Behavioural fixes applied
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `lib/logging/app_log.dart`: a ~500-entry ring buffer, no network.
- Surface it read-only on the Developer/Advanced screen (see §4-6.4).
- Sweep the swallowed catches; rule: a swallow is legal only if the op is optional AND logs.
- Behavioural fixes during the sweep: failed urgent-low must not advance `_lastFired`; `runStartup` records per-job failures.
- Test: ring-buffer unit test (cap, eviction); assert swept catches log; behavioural tests for `_lastFired` and `runStartup` failure recording; add/extend unit tests under `test/`.
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §3.D (P1-8)
- Effort: S–M
- Depends on: pairs with §4-6.4
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:29
---
detail-needed (2026-07-06, goal triage): Defines the app_log ring-buffer design + a 43-site catch sweep across the codebase; foundational and wide. Want the logging API/approach confirmed before the sweep.
---
<!-- COMMENTS:END -->
