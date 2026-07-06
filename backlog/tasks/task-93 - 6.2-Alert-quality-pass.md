---
id: TASK-93
title: 6.2 Alert quality pass
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:47'
labels:
  - roadmap
  - §6
  - alerts
  - "\U0001F512 safety"
dependencies: []
priority: medium
ordinal: 93000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude's alerts work but lack polish — snoozing/acknowledging, avoiding repeat nagging, and not alerting during a workout.

**Reason for change.** These quality-of-life improvements make alerts less annoying and more trustworthy, so people don't start ignoring them. Builds on the alert decision-core and per-time-of-day thresholds.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Snooze + acknowledge semantics
- [ ] #2 Smarter dedup prevents repeat spam
- [ ] #3 Exercise-mode alert-suppression nuance
- [ ] #4 Covered by alert decision-core tests (§3.C step 1)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Snooze/acknowledge semantics, smarter dedup (no repeat spam), do-not-alert-during-exercise nuances. Build on the §3.C decision-core and §4-2.3 per-TOD thresholds.

**Testing.** Decision-core matrix tests cover snooze/ack/dedup/exercise-suppression. Add/extend unit tests under `test/`. `flutter analyze` clean, `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §6
- Effort: M
- Flags: 🔒 safety
- Roadmap status: open
<!-- SECTION:NOTES:END -->
