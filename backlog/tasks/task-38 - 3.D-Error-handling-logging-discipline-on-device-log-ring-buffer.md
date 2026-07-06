---
id: TASK-38
title: 3.D Error-handling & logging discipline + on-device log ring buffer
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
labels:
  - roadmap
  - §3
  - architecture
  - logging
dependencies: []
priority: medium
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
43 bare catch(_){} (33 in providers.dart). Add lib/logging/app_log.dart: an on-device ring buffer (~500 entries, no network), surfaced read-only (this IS the on-device crash/error logging infra — see §4-6.4). Sweep rule: a swallow is legal only if the op is optional AND logs. Behavioural fixes during sweep: failed urgent-low must not advance _lastFired; runStartup records per-job failures.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 app_log.dart ring buffer (~500 entries, no network)
- [ ] #2 Surfaced read-only in the Developer/Advanced screen
- [ ] #3 Swept catches log or are removed
- [ ] #4 Behavioural fixes applied
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §3.D (P1-8)
Effort: S–M
Depends on: pairs with §4-6.4
Roadmap status: open
<!-- SECTION:NOTES:END -->
