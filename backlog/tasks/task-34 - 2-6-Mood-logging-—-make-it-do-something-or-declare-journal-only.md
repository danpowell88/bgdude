---
id: TASK-34
title: 2-6 Mood logging — make it do something or declare journal-only
status: To Do
assignee: []
created_date: '2026-07-06 03:10'
updated_date: '2026-07-06 03:27'
labels:
  - roadmap
  - §2
  - needs-exploration
dependencies: []
priority: low
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Captured as an annotation today. Either wire it to §4-4.3 (mood↔glucose correlation) or declare it journal-only in the guide.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Source: ROADMAP §2 item 2-6
Effort: S
Depends on: §4-4.3 (if wired)
⚠ NEEDS MORE EXPLORATION: Decide the direction — wire to correlation analysis vs journal-only. Small but a product decision, not just code.
<!-- SECTION:NOTES:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Decision recorded: wire mood to §4-4.3 correlation OR declare it journal-only
- [ ] #2 If wired: mood tags feed 4-4.3 (TASK-67)
- [ ] #3 If journal-only: the user guide states mood is not analysed
- [ ] #4 No "captured but unused" dangling state remains
<!-- AC:END -->
