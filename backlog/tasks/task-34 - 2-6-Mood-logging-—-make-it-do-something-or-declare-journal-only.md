---
id: TASK-34
title: 2-6 Mood logging — make it do something or declare journal-only
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 04:52'
labels:
  - roadmap
  - §2
  - needs-exploration
  - detail-needed
dependencies: []
priority: low
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Background.** bgdude lets you tag your mood, but nothing is done with that tag — it's recorded and then ignored.

**Reason for change.** Recording something and never using it is misleading. Either the mood tag should drive an insight (the mood-vs-glucose correlation) or the guide should say plainly that it's just a journal entry.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Decision recorded: wire mood to §4-4.3 correlation OR declare it journal-only
- [ ] #2 If wired: mood tags feed 4-4.3 (TASK-67)
- [ ] #3 If journal-only: the user guide states mood is not analysed
- [ ] #4 No "captured but unused" dangling state remains
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
**Technical notes.** Decide: wire mood into §4-4.3 (mood↔glucose correlation, TASK-67) OR declare it journal-only in the user guide and stop implying analysis.

**Testing.** If wired: the correlation consumes mood tags (see TASK-67 tests). If journal-only: the guide states it; no dangling "unused" state. Add/extend unit tests under `test/`. `flutter analyze` clean, `flutter test` green before commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Source: ROADMAP §2 item 2-6
- Effort: S
- Depends on: §4-4.3 (if wired)
- ⚠ NEEDS MORE EXPLORATION: Decide the direction — wire to correlation analysis vs journal-only. Small but a product decision, not just code.

detail-needed (2026-07-06, goal triage): Decision: wire mood into the correlation (TASK-67) or declare it journal-only. Product call.
<!-- SECTION:NOTES:END -->
