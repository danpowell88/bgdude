---
id: TASK-93
title: Alert quality pass
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 19:08'
labels:
  - roadmap
  - alerts
  - "\U0001F512 safety"
  - detail-needed
milestone: m-7
dependencies: []
priority: medium
ordinal: 102900
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
- [x] #3 Exercise-mode alert-suppression nuance
- [x] #4 Covered by alert decision-core tests (TASK-37 step 1)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
- Add snooze/acknowledge semantics.
- Smarter dedup (no repeat spam).
- Do-not-alert-during-exercise nuances.
- Build on the TASK-37 decision-core and the per-TOD thresholds (4-2.3, TASK-56..60 area).
- Decision-core matrix tests cover snooze/ack/dedup/exercise-suppression; add/extend unit tests under `test/`.
- Verify: `flutter analyze` clean, `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP section 6
- Effort: M
- Flags: 🔒 safety
- Roadmap status: open
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: Claude
created: 2026-07-06 05:30
---
detail-needed (2026-07-06, goal triage): Alert quality (snooze/ack/dedup) is best built on the §3.C pure decision-core (TASK-37, detail-needed); blocked on that.
---

author: Claude
created: 2026-07-06 19:08
---
AC#3 (exercise-mode alert-suppression) + AC#4 (decision-core tests) delivered (commit above): AlertMonitor.evaluate gains suppressPredictedHigh, wired to the active exercise plan; lows/urgent-lows are never suppressed; matrix tests added. AC#2 (smarter dedup) is PARTLY in place — the alert loop already gates each kind on a cooldown and the 'currentMgdl > lowMgdl' guard avoids re-alerting the same dip; a fuller 'don't re-alert until the value recovers and dips again' needs a small state machine (per-excursion tracking) — bounded but wants a design nod on the recovery threshold. AC#1 (snooze + acknowledge) is a real stateful feature needing notification action buttons + persisted per-alert snooze state + UI — best done as a focused unit (and it's a UX decision how long snooze lasts per category). Flagged for that focused pass.
---
<!-- COMMENTS:END -->
