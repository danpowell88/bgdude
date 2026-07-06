---
id: TASK-39
title: Inject the clock
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 08:05'
labels:
  - roadmap
  - architecture
  - detail-needed
milestone: m-6
dependencies: []
priority: medium
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** A lot of the code reads "the current time" directly (78 places). Anything that behaves differently depending on the time — quiet hours, alert cool-downs, scheduled jobs — can't be tested reliably, because a test can't pin the clock.

**Reason for change.** Injecting the clock (passing "what time is it" in, rather than reading it globally) makes all that time-dependent behaviour testable and deterministic.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 clockProvider added
- [ ] #2 Injected into AppJobs/AlertService/persisted notifiers
- [ ] #3 Time-relative behaviour testable
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add `clockProvider` (`DateTime Function()`).
- Constructor-inject it into `AppJobs`/`AlertService`/persisted notifiers during the TASK-35 moves.
- Keep `analytics`/`ml` explicit-`DateTime` style; do not sweep display-only UI usages.
- Refactor must be behaviour-preserving: full `flutter test` + `flutter analyze` green before and after.
- Add the new unit tests the refactor unlocks: inject a fixed clock and assert time-relative behaviour (quiet hours, dedup windows, job cadence).
- Verify: `flutter analyze` clean, `flutter test` green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 3.E
- Effort: S–M
- Depends on: moves with 3.A
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:23
---
detail-needed (2026-07-06, goal triage): Clock injection moves with §3.A (constructor-injecting AppJobs/AlertService/notifiers); do it as part of that refactor, not standalone.
---
<!-- COMMENTS:END -->
