---
id: TASK-39
title: 3.E Inject the clock
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:44'
labels:
  - roadmap
  - §3
  - architecture
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
**Technical notes.** Add clockProvider (DateTime Function()), constructor-injected into AppJobs/AlertService/persisted notifiers during the §3.A moves. Keep analytics/ml explicit-DateTime style; do not sweep display-only UI usages.

**Testing.** Tests inject a fixed clock and assert time-relative behaviour (quiet hours, dedup windows, job cadence). Refactor must be behaviour-preserving: full `flutter test` + `flutter analyze` green before and after; add the new unit tests the refactor unlocks.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §3.E
- Effort: S–M
- Depends on: moves with 3.A
- Roadmap status: open
<!-- SECTION:NOTES:END -->
